"""Create initial prototype workbooks. Refuses to overwrite designer-edited files."""
from pathlib import Path
from openpyxl import Workbook
from openpyxl.styles import PatternFill, Font, Alignment
from openpyxl.comments import Comment

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'table/xlsx'
OUT.mkdir(parents=True, exist_ok=True)
translations = []

def text(cn, tw, en):
    return (cn, tw, en)

def table(filename, name, fields, rows):
    path = OUT / filename
    if path.exists():
        raise RuntimeError(f'Refusing to overwrite source workbook: {path}')
    wb = Workbook()
    ws = wb.active
    ws.title = name
    for row in [[f[0] for f in fields], [f[1] for f in fields], ['cs']*len(fields), [f[2] for f in fields]]:
        ws.append(row)
    for col, field in enumerate(fields, 1):
        if len(field) > 3:
            ws.cell(1, col).comment = Comment(field[3], 'schema')
    for row in rows:
        values = []
        for field, value in zip(fields, row):
            if isinstance(value, tuple):
                translations.append([f'{name}_{field[0]}_{row[0]}', *value])
                value = value[0]
            values.append(value)
        ws.append(values)
    for cells in ws.iter_rows(min_row=1, max_row=4):
        for cell in cells:
            cell.fill = PatternFill('solid', fgColor='223545')
            cell.font = Font(color='F4D59B', bold=True)
            cell.alignment = Alignment(horizontal='center', vertical='center', wrap_text=True)
    ws.freeze_panes = 'B5'
    for col in ws.columns:
        ws.column_dimensions[col[0].column_letter].width = 25
    wb.save(path)

table('技能.xlsx', 'Skill', [('ID','pk int32','技能编号'),('Name','i18n','技能名称'),('Description','i18n','技能说明'),('Multiplier','int32','技能伤害百分比'),('Every','int32','每几次行动释放')], [
[1,text('破晓斩','破曉斬','Dawn Slash'),text('挥剑攻击前方敌人。','揮劍攻擊前方敵人。','Strike an enemy with a blade of dawn.'),180,3],
[2,text('星火箭','星火箭','Ember Arrow'),text('射出贯穿黑暗的箭矢。','射出貫穿黑暗的箭矢。','Loose an arrow through the darkness.'),210,3],
[3,text('霜之回响','霜之迴響','Frost Echo'),text('凝聚寒霜，重击敌人。','凝聚寒霜，重擊敵人。','Gather frost into a powerful strike.'),230,4],
[4,text('圣光裁决','聖光裁決','Light Verdict'),text('以圣光击退敌人。','以聖光擊退敵人。','Drive enemies back with sacred light.'),200,3],
[5,text('荆棘突刺','荊棘突刺','Thorn Pierce'),text('荆棘之力集中于一击。','荊棘之力集中於一擊。','Channel the forest into a piercing blow.'),240,4],
[6,text('暮影刃','暮影刃','Dusk Blade'),text('从阴影中发起迅捷一击。','從陰影中發起迅捷一擊。','Deliver a swift strike from the shadows.'),190,2]])
table('英雄.xlsx','Hero', [('ID','pk int32','英雄编号'),('Name','i18n','英雄名'),('Title','i18n','称号'),('Faction','i18n','阵营'),('Role','i18n','职业'),('Description','i18n','英雄介绍'),('Attack','int32','基础攻击'),('Health','int32','基础生命'),('Defense','int32','基础防御'),('SkillID','int32','技能','fk:Skill.ID'),('PortraitColor','string','展示色')], [
[1,text('莱昂','萊昂','Leon'),text('晨曦守望','晨曦守望','Dawn Warden'),text('耀光','耀光','Lightbearer'),text('战士','戰士','Warrior'),text('将最后一道曙光守在剑锋之上。','將最後一道曙光守在劍鋒之上。','He carries the last light of dawn upon his blade.'),38,440,15,1,'dba35e'],
[2,text('艾琳','艾琳','Eryn'),text('逐星游侠','逐星遊俠','Star Ranger'),text('绿裔','綠裔','Wildborn'),text('游侠','遊俠','Ranger'),text('循着星光，箭矢从不迷失方向。','循著星光，箭矢從不迷失方向。','Guided by starlight, her arrows never lose their way.'),52,290,6,2,'72b7a0'],
[3,text('露米','露米','Lumi'),text('霜月贤者','霜月賢者','Frost Sage'),text('星辉','星輝','Celestial'),text('法师','法師','Mage'),text('古老的冰晶记载着世界的回声。','古老的冰晶記載著世界的迴聲。','Ancient ice remembers the echoes of the world.'),60,250,4,3,'86a8d5'],
[4,text('瑟拉','瑟拉','Sera'),text('圣辉骑士','聖輝騎士','Radiant Knight'),text('耀光','耀光','Lightbearer'),text('坦克','坦克','Tank'),text('以坚盾守护每一个同行之人。','以堅盾守護每一個同行之人。','Her shield is a promise to every companion.'),30,590,23,4,'d5bf79'],
[5,text('薇洛','薇洛','Willow'),text('森语使者','森語使者','Grove Herald'),text('绿裔','綠裔','Wildborn'),text('法师','法師','Mage'),text('风与枝叶低语，回应远征的呼唤。','風與枝葉低語，回應遠征的呼喚。','Leaves and wind answer the call of the expedition.'),48,330,8,5,'9fae77'],
[6,text('诺克斯','諾克斯','Nox'),text('暮色行者','暮色行者','Dusk Walker'),text('暮影','暮影','Duskborn'),text('刺客','刺客','Assassin'),text('无声穿过迷雾，追寻失落的誓言。','無聲穿過迷霧，追尋失落的誓言。','He crosses the mist in pursuit of a forgotten oath.'),57,280,5,6,'ad8cc3']])
table('装备.xlsx','Equipment',[('ID','pk int32','装备编号'),('Name','i18n','装备名称'),('Description','i18n','装备说明'),('Attack','int32','攻击加成'),('Health','int32','生命加成'),('RequiredLevel','int32','穿戴等级')],[
[101,text('旅人长剑','旅人長劍',"Traveler's Blade"),text('踏上旅途时最可靠的伙伴。','踏上旅途時最可靠的夥伴。','A dependable companion for the road ahead.'),18,30,1],
[102,text('守誓之刃','守誓之刃','Oathkeeper'),text('铭刻誓言的旧剑，依然锋利。','銘刻誓言的舊劍，依然鋒利。','An old blade, its oath and edge unbroken.'),30,60,3],
[103,text('星陨圣剑','星隕聖劍','Starfall'),text('星光凝于锋刃，等待真正的勇者。','星光凝於鋒刃，等待真正的勇者。','Starlight sleeps in its edge, awaiting a worthy hero.'),55,100,5]])
names=[text('薄雾林地','薄霧林地','Mistwood'),text('失落哨站','失落哨站','Lost Outpost'),text('月影古桥','月影古橋','Moonlit Bridge'),text('回声峡谷','迴聲峽谷','Echo Canyon'),text('沉眠遗迹','沉眠遺跡','Sleeping Ruins'),text('王城之门','王城之門','Citadel Gate')]
table('关卡.xlsx','Stage',[('ID','pk int32','关卡编号'),('Name','i18n','关卡名'),('Description','i18n','关卡描述'),('EnemyName','i18n','敌人名'),('EnemyAttack','int32','敌人攻击'),('EnemyHealth','int32','敌人生命'),('EnemyDefense','int32','敌人防御'),('Gold','int32','首通金币'),('Experience','int32','首通经验')],[[i+1,n,text('清除迷雾中的敌人，继续远征。','清除迷霧中的敵人，繼續遠征。','Clear the path through the mist and continue your journey.'),text('迷雾守卫','迷霧守衛','Mist Sentinel'),22+i*9,170+i*100,4+i*3,120+i*40,80+i*25] for i,n in enumerate(names)])
table('成长与挂机.xlsx','Rules',[('ID','pk int32','规则编号'),('Version','string','配置版本'),('InitialGold','int32','初始金币'),('InitialExperience','int32','初始经验'),('LevelGold','int32','升级金币系数'),('LevelExperience','int32','升级经验系数'),('MaxLevel','int32','最高等级'),('IdleGoldPerMinute','int32','基础挂机金币每分钟'),('IdleExperiencePerMinute','int32','基础挂机经验每分钟'),('IdleCapSeconds','int32','挂机上限秒'),('AttackPerLevel','int32','每级攻击成长'),('HealthPerLevel','int32','每级生命成长'),('DefensePerLevel','int32','每级防御成长')],[[1,'ember-1',1200,900,35,25,20,60,30,43200,8,65,2]])
table('I18N.xlsx','I18N',[('ID','pk string','稳定翻译键'),('Cn','string','简体中文'),('Tn','string','繁体中文'),('En','string','英文')],translations)
print('Created 6 workbooks; dynamic translations:',len(translations))
