"""Adapt the vendor serializer to nested proto paths and cross-file types."""

import os
import re
from pathlib import Path, PurePosixPath
import sys

from google.protobuf.compiler import plugin_pb2

sys.path.insert(0, str(Path(__file__).parent / "protoc-gen-gdscript-simple"))
import generate_message as vendor


def normalize_generated(content):
    """Repair reset/unknown-field paths in generated output without changing the vendor."""
    # Message presence resets to null; generated message classes have no clear() API.
    content = re.sub(
        r"(?m)^\t\tif self\.(\w+) != null:[ \t]*self\.\1\.clear\(\)\r?$",
        r"\t\tself.\1 = null", content,
    )
    content = re.sub(r"(?m)^(\t\tself\.clear_\w+)[ \t]*\r?$", r"\1()", content)
    # The vendor serializes the backing scalar array, so a reset must clear both size and storage.
    content = re.sub(
        r"(?m)^(\tfunc clear_(\w+)\(\) -> void:\r?\n)(\t\tself\._\2_size = 0)",
        r"\1\t\tself._\2.clear()\n\3", content,
    )
    # Fail closed on unknown fields instead of leaving the parser cursor in an endless loop.
    content = content.replace("\t\t\t\t_:\n\t\t\t\t\tpass", "\t\t\t\t_:\n\t\t\t\t\treturn -1")
    # Propagate nested decoding failures instead of advancing with an invalid length.
    content = content.replace("GDScriptUtils.decode_message(", "Wire.decode_message(")
    content = re.sub(
        r"(?m)^([ \t]+)var field_value = (.+decode_\w+\([^\n]+\))$",
        r"\1var field_value = \2\n\1if field_value[GDScriptUtils.SIZE_KEY] <= 0:\n\1\treturn -1", content,
    )
    return content


def generate(request):
    prefix = os.environ.get("PROTOC_GEN_GDSCRIPT_PREFIX", "").rstrip("/")
    if not prefix.startswith("res://"):
        raise ValueError("PROTOC_GEN_GDSCRIPT_PREFIX must be a res:// directory")

    descriptors = {file.name: file for file in request.proto_file}
    owners = {}

    def register(file, message, parent=""):
        name = parent + message.name
        owners["." + file.package + "." + name] = (file.name, name.split(".")[0])
        for child in message.nested_type:
            register(file, child, name + ".")

        for enum in message.enum_type:
            owners["." + file.package + "." + name + "." + enum.name] = (file.name, name.split(".")[0])

    for file in request.proto_file:
        for message in file.message_type:
            register(file, message)

        for enum in file.enum_type:
            owners["." + file.package + "." + enum.name] = (file.name, enum.name)

    def imports(file):
        aliases = {}

        def visit(message):
            for field in message.field:
                if not field.type_name:
                    continue

                owner, symbol = owners[field.type_name]
                if owner == file.name:
                    continue

                if descriptors[owner].package != file.package:
                    raise ValueError("Cross-package GDScript types are not supported: " + field.type_name)

                aliases[symbol] = owner

            for child in message.nested_type:
                visit(child)

        for message in file.message_type:
            visit(message)

        base = vendor.get_protobuf_base_path()
        lines = [f'const GDScriptUtils = preload("{base}/proto/GDScriptUtils.gd")',
                 f'const Message = preload("{base}/proto/Message.gd")',
                 'const Wire = preload("res://protobuf/runtime/wire.gd")']

        for symbol, owner in sorted(aliases.items()):
            lines.append(f'const {symbol} = preload("{prefix}/{owner}.gd").{symbol}')

        return "\n".join(lines) + "\n\n"

    response = plugin_pb2.CodeGeneratorResponse()
    original_imports = vendor.generate_imports
    original_parser = vendor.generate_parse_from_string_methods

    def checked_parser(message, gd_message, indent):
        # Hook the descriptor-level generator, including nested message classes.
        fields = []
        for field in message.field:
            wire_type = {1: 1, 2: 5, 6: 1, 7: 5, 9: 2, 11: 2, 12: 2, 15: 5, 16: 1}.get(field.type, 0)
            fields.append(f"{field.number}: {wire_type}")

        content = original_parser(message, gd_message, indent)
        signature = f"{indent}func ParseFromBytes(data: PackedByteArray) -> int:\n"
        check = f"{indent}\tif not Wire.validate(data, {{" + ", ".join(fields) + f"}}):\n{indent}\t\treturn -1\n\n"
        return content.replace(signature, signature + check, 1)

    try:
        vendor.generate_imports = imports
        vendor.generate_parse_from_string_methods = checked_parser
        for name in request.file_to_generate:
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts:
                raise ValueError("Unsafe proto output path: " + name)

            single = plugin_pb2.CodeGeneratorRequest()
            single.CopyFrom(request)
            del single.file_to_generate[:]
            single.file_to_generate.append(name)
            generated = vendor.generate_gdscript(single)
            if generated.error or len(generated.file) != 1:
                raise ValueError(generated.error or "Expected one GDScript per proto")

            output = response.file.add()
            output.name = name + ".gd"
            output.content = normalize_generated(generated.file[0].content)
    finally:
        vendor.generate_imports = original_imports
        vendor.generate_parse_from_string_methods = original_parser

    return response


if __name__ == "__main__":
    result = plugin_pb2.CodeGeneratorResponse()
    try:
        request = plugin_pb2.CodeGeneratorRequest.FromString(sys.stdin.buffer.read())
        result = generate(request)
    except Exception as error:
        result.error = str(error)

    sys.stdout.buffer.write(result.SerializeToString())
