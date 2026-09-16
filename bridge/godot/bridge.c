// Thin Windows x64 C ABI adapter. Gameplay remains entirely in gamecore.dll.
#include "gdextension_interface.h"
#include <windows.h>
#include <stdint.h>
#include <stdlib.h>

// Godot 4.7 Windows x64: String and StringName are 8 bytes (extension_api.json).
typedef uint64_t GString;
static GDExtensionClassLibraryPtr library;
static GString class_name, parent_name;
static GDExtensionInterfaceStringNameNewWithUtf8Chars name_new;
static GDExtensionInterfaceStringNewWithUtf8Chars string_new;
static GDExtensionInterfaceStringToUtf8Chars string_utf8;
static GDExtensionInterfaceClassdbConstructObject3 construct;
static GDExtensionInterfaceObjectSetInstance set_instance;
static GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
static GDExtensionInterfaceVariantGetType variant_type;
static GDExtensionVariantFromTypeConstructorFunc from_string;
static GDExtensionTypeFromVariantConstructorFunc to_string;
static GDExtensionPtrDestructor destroy_string, destroy_name;
typedef char *(*CoreCall)(const char *);
typedef void (*CoreFree)(void *);
static HMODULE core_module;
static CoreCall core_call;
static CoreFree core_free;

static char *utf8(GDExtensionConstStringPtr value) {
    GDExtensionInt size = string_utf8(value, NULL, 0);
    char *buffer = calloc((size_t)size + 1, 1);
    if (buffer) string_utf8(value, buffer, size);
    return buffer;
}

static void invoke(GDExtensionConstStringPtr path, GDExtensionConstStringPtr input,
                   GDExtensionUninitializedStringPtr output) {
    const char *failure = "{\"ok\":false,\"code\":\"native_unavailable\"}";
    if (!core_module) {
        char *raw = utf8(path);
        if (!raw) { string_new(output, failure); return; }
        int count = MultiByteToWideChar(CP_UTF8, 0, raw, -1, NULL, 0);
        wchar_t *wide = calloc((size_t)count, sizeof(wchar_t));
        if (wide) {
            MultiByteToWideChar(CP_UTF8, 0, raw, -1, wide, count);
            core_module = LoadLibraryExW(wide, NULL, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
            free(wide);
        }
        free(raw);
        if (core_module) {
            core_call = (CoreCall)GetProcAddress(core_module, "GameCall");
            core_free = (CoreFree)GetProcAddress(core_module, "GameFree");
        }
    }
    // Go runtime is process resident: never unload or hot-reload its DLL.
    if (!core_call || !core_free) { string_new(output, failure); return; }
    char *request = utf8(input);
    if (!request) { string_new(output, failure); return; }
    char *response = core_call(request);
    string_new(output, response ? response : failure);
    if (response) core_free(response);
    free(request);
}

static GDExtensionObjectPtr create_instance(void *unused, GDExtensionBool notify) {
    (void)unused; (void)notify;
    GDExtensionObjectPtr object = construct(&parent_name);
    set_instance(object, &class_name, calloc(1, 1));
    return object;
}
static void free_instance(void *unused, GDExtensionClassInstancePtr instance) {
    (void)unused; free(instance);
}
static void call(void *userdata, GDExtensionClassInstancePtr instance,
                 const GDExtensionConstVariantPtr *args, GDExtensionInt argc,
                 GDExtensionVariantPtr result, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    error->error = GDEXTENSION_CALL_OK;
    if (argc != 2) {
        error->error = argc < 2 ? GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS : GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
        error->expected = 2; return;
    }
    for (int i = 0; i < 2; i++) {
        if (variant_type(args[i]) != GDEXTENSION_VARIANT_TYPE_STRING) {
            error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
            error->argument = i; error->expected = GDEXTENSION_VARIANT_TYPE_STRING; return;
        }
    }
    GString path, input, output;
    to_string(&path, (GDExtensionVariantPtr)args[0]);
    to_string(&input, (GDExtensionVariantPtr)args[1]);
    invoke(&path, &input, &output);
    from_string(result, &output);
    destroy_string(&path); destroy_string(&input); destroy_string(&output);
}
static void ptrcall(void *userdata, GDExtensionClassInstancePtr instance,
                    const GDExtensionConstTypePtr *args, GDExtensionTypePtr result) {
    (void)userdata; (void)instance;
    invoke(args[0], args[1], result);
}
static void initialize(void *unused, GDExtensionInitializationLevel level) {
    (void)unused;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    name_new(&class_name, "GameCoreBridge"); name_new(&parent_name, "RefCounted");
    GDExtensionClassCreationInfo6 info = {0};
    info.is_exposed = 1; info.create_instance_func = create_instance; info.free_instance_func = free_instance;
    register_class(library, &class_name, &parent_name, &info);
    GString method_name, path_name, request_name, empty_name, empty_string;
    name_new(&method_name, "call_core"); name_new(&path_name, "library_path");
    name_new(&request_name, "request_json"); name_new(&empty_name, ""); string_new(&empty_string, "");
    GDExtensionPropertyInfo ret = {GDEXTENSION_VARIANT_TYPE_STRING, &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionPropertyInfo args[2] = {ret, ret};
    args[0].name = &path_name; args[1].name = &request_name;
    GDExtensionClassMethodArgumentMetadata metadata[2] = {0, 0};
    GDExtensionClassMethodInfo method = {0};
    method.name = &method_name; method.call_func = call; method.ptrcall_func = ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL; method.has_return_value = 1;
    method.return_value_info = &ret; method.argument_count = 2;
    method.arguments_info = args; method.arguments_metadata = metadata;
    register_method(library, &class_name, &method);
    destroy_name(&method_name); destroy_name(&path_name); destroy_name(&request_name);
    destroy_name(&empty_name); destroy_string(&empty_string);
}
static void terminate(void *unused, GDExtensionInitializationLevel level) {
    (void)unused;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    unregister_class(library, &class_name);
    destroy_name(&class_name); destroy_name(&parent_name);
}

__declspec(dllexport) GDExtensionBool game_bridge_init(GDExtensionInterfaceGetProcAddress get,
        GDExtensionClassLibraryPtr lib, GDExtensionInitialization *initialization) {
    library = lib;
#define LOAD(variable, type, name) variable = (type)get(name); if (!variable) return 0
    LOAD(name_new, GDExtensionInterfaceStringNameNewWithUtf8Chars, "string_name_new_with_utf8_chars");
    LOAD(string_new, GDExtensionInterfaceStringNewWithUtf8Chars, "string_new_with_utf8_chars");
    LOAD(string_utf8, GDExtensionInterfaceStringToUtf8Chars, "string_to_utf8_chars");
    LOAD(construct, GDExtensionInterfaceClassdbConstructObject3, "classdb_construct_object3");
    LOAD(set_instance, GDExtensionInterfaceObjectSetInstance, "object_set_instance");
    LOAD(register_class, GDExtensionInterfaceClassdbRegisterExtensionClass6, "classdb_register_extension_class6");
    LOAD(register_method, GDExtensionInterfaceClassdbRegisterExtensionClassMethod, "classdb_register_extension_class_method");
    LOAD(unregister_class, GDExtensionInterfaceClassdbUnregisterExtensionClass, "classdb_unregister_extension_class");
    LOAD(variant_type, GDExtensionInterfaceVariantGetType, "variant_get_type");
    from_string = ((GDExtensionInterfaceGetVariantFromTypeConstructor)get("get_variant_from_type_constructor"))(GDEXTENSION_VARIANT_TYPE_STRING);
    to_string = ((GDExtensionInterfaceGetVariantToTypeConstructor)get("get_variant_to_type_constructor"))(GDEXTENSION_VARIANT_TYPE_STRING);
    GDExtensionInterfaceVariantGetPtrDestructor destructor = (GDExtensionInterfaceVariantGetPtrDestructor)get("variant_get_ptr_destructor");
    destroy_string = destructor(GDEXTENSION_VARIANT_TYPE_STRING);
    destroy_name = destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
    initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    initialization->userdata = NULL; initialization->initialize = initialize; initialization->deinitialize = terminate;
    return 1;
}
