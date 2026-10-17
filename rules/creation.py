"""Authoritative level-one character creation, SRD 5.1 / 2014 rules.

Engine vocation is deliberately separate from class identity.
"""
import re
from .catalog2014 import collection
from .choices import class_skill_options,skills as validate_class_skills

ABILITIES = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA']
COSTS = {8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9}
RACES = {
    'human': dict(name='Humano', bonuses=[1]*6, speed=30, traits=['Idioma adicional']),
    'elf': dict(name='Alto Elfo', bonuses=[0,2,0,1,0,0], speed=30, traits=['Visão no escuro', 'Ancestralidade feérica', 'Transe', 'Truque de mago', 'Percepção']),
    'dwarf': dict(name='Anão da Colina', bonuses=[0,0,2,0,1,0], speed=25, traits=['Visão no escuro', 'Resiliência anã', 'Robustez anã (+1 PV por nível)']),
    'halfling': dict(name='Halfling Pés-Leves', bonuses=[0,2,0,0,0,1], speed=25, traits=['Sortudo', 'Bravura', 'Agilidade halfling', 'Furtividade natural']),
    'half-orc': dict(name='Meio-Orc', bonuses=[2,0,1,0,0,0], speed=30, traits=['Visão no escuro','Ameaçador: Intimidação','Resistência Implacável','Ataques Selvagens'], skills=['Intimidation']),
    'dragonborn': dict(name='Draconato',bonuses=[2,0,0,0,0,1],speed=30,traits=['Ancestralidade Dracônica','Arma de Sopro','Resistência Dracônica'],ancestries=['black','blue','brass','bronze','copper','gold','green','red','silver','white']),
    'gnome': dict(name='Gnomo das Rochas',bonuses=[0,0,1,2,0,0],speed=25,traits=['Visão no escuro','Esperteza Gnômica','Conhecimento de Artífice','Engenhoqueiro']),
    'half-elf': dict(name='Meio-Elfo',bonuses=[0,0,0,0,0,2],speed=30,traits=['Visão no escuro','Ancestralidade Feérica','Versatilidade em Perícias'],ability_choices=2,skill_choices=2),
    'tiefling': dict(name='Tiefling',bonuses=[0,0,0,1,0,2],speed=30,traits=['Visão no escuro','Resistência Infernal','Legado Infernal']),
}
RACE_IDS={key:index for index,key in enumerate(['human','elf','dwarf','halfling','dragonborn','gnome','half-elf','half-orc','tiefling'],1)}
CLASSES = {
    'fighter': dict(name='Guerreiro', hit_die=10, saves=['STR','CON'], spell=None, array=[15,13,14,8,12,10], armor='chain', equipment=['Cota de malha','Escudo','Espada longa','Besta leve','Pacote de explorador'], features=['Estilo de luta: Defesa', 'Retomar o fôlego'], skills=['Athletics','Perception']),
    'rogue': dict(name='Ladino', hit_die=8, saves=['DEX','INT'], spell=None, array=[12,15,13,14,10,8], armor='leather', equipment=['Armadura de couro','Rapieira','Arco curto','Duas adagas','Ferramentas de ladrão','Pacote de assaltante'], features=['Ataque furtivo 1d6','Especialização: Stealth e Sleight of Hand','Gíria de ladrões'], skills=['Stealth','Sleight of Hand','Acrobatics','Investigation']),
    'cleric': dict(name='Clérigo', hit_die=8, saves=['WIS','CHA'], spell='WIS', array=[13,12,14,8,15,10], armor='chain', equipment=['Cota de malha','Escudo','Maça','Besta leve','Símbolo sagrado','Pacote de sacerdote'], features=['Domínio da Vida','Discípulo da Vida','Conjuração preparada'], skills=['Medicine','Religion']),
    'wizard': dict(name='Mago', hit_die=6, saves=['INT','WIS'], spell='INT', array=[8,14,13,15,12,10], armor='none', equipment=['Cajado','Foco arcano','Grimório','Pacote de estudioso'], features=['Recuperação arcana','Conjuração por grimório'], skills=['Arcana','Investigation']),
    'barbarian': dict(name='Bárbaro', hit_die=12, saves=['STR','CON'], spell=None, array=[15,13,14,8,12,10], armor='unarmored', equipment=['Machado grande','Duas machadinhas','Quatro azagaias','Pacote de explorador'], features=['Fúria','Defesa sem Armadura'], skills=['Athletics','Survival']),
    'monk': dict(name='Monge', hit_die=8, saves=['STR','DEX'], spell=None, array=[12,15,13,8,14,10], armor='unarmored', equipment=['Espada curta','Dez dardos','Pacote de explorador'], features=['Artes Marciais','Defesa sem Armadura'], skills=['Acrobatics','Stealth']),
    'paladin': dict(name='Paladino', hit_die=10, saves=['WIS','CHA'], spell='CHA', array=[15,10,13,8,12,14], armor='chain', equipment=['Cota de malha','Escudo','Espada longa','Cinco azagaias','Símbolo sagrado','Pacote de sacerdote'], features=['Sentido Divino','Impor as Mãos: reserva de 5 PV'], skills=['Athletics','Persuasion']),
    'bard':dict(name='Bardo',hit_die=8,saves=['DEX','CHA'],spell='CHA',array=[8,14,13,10,12,15],armor='leather',equipment=['Rapieira','Armadura de couro','Adaga','Alaúde','Pacote de artista'],features=['Inspiração Bárdica d6','Conjuração'],skills=['Performance','Persuasion','Deception']),
    'druid':dict(name='Druida',hit_die=8,saves=['INT','WIS'],spell='WIS',array=[8,14,13,12,15,10],armor='leather',equipment=['Armadura de couro','Escudo de madeira','Cajado','Foco druídico','Pacote de explorador'],features=['Druídico','Conjuração preparada'],skills=['Nature','Medicine']),
    'ranger':dict(name='Patrulheiro',hit_die=10,saves=['STR','DEX'],spell='WIS',array=[12,15,14,8,13,10],armor='scale',equipment=['Brunea','Duas espadas curtas','Arco longo','Vinte flechas','Pacote de explorador'],features=['Inimigo Favorito','Explorador Nato'],skills=['Perception','Survival','Nature']),
    'sorcerer':dict(name='Feiticeiro',hit_die=6,saves=['CON','CHA'],spell='CHA',array=[8,14,13,12,10,15],armor='draconic',equipment=['Adaga','Besta leve','Vinte virotes','Foco arcano','Pacote de explorador'],features=['Linhagem Dracônica','Resiliência Dracônica','Conjuração'],skills=['Arcana','Persuasion']),
    'warlock':dict(name='Bruxo',hit_die=8,saves=['WIS','CHA'],spell='CHA',array=[8,14,13,12,10,15],armor='leather',equipment=['Armadura de couro','Adaga','Besta leve','Vinte virotes','Foco arcano','Pacote de estudioso'],features=['Pacto Infernal','Bênção do Obscuro','Magia de Pacto'],skills=['Arcana','Intimidation']),
}
CLASS_IDS={key:index for index,key in enumerate(['fighter','rogue','cleric','wizard','barbarian','bard','druid','monk','paladin','ranger','sorcerer','warlock'],1)}
BACKGROUNDS = {'acolyte': dict(name='Acólito', skills=['Insight','Religion'])}
SKILL_ABILITIES = dict(Acrobatics='DEX', Animal_Handling='WIS', Arcana='INT', Athletics='STR',
    Deception='CHA', History='INT', Insight='WIS', Intimidation='CHA', Investigation='INT',
    Medicine='WIS', Nature='INT', Perception='WIS', Performance='CHA', Persuasion='CHA',
    Religion='INT', Sleight_of_Hand='DEX', Stealth='DEX', Survival='WIS')

def catalog():
    classes={}
    for index,(key,value) in enumerate(CLASSES.items(),1):
        count,options=class_skill_options(key)
        classes[key]=dict(value,id=CLASS_IDS[key],skill_count=count,skill_options=options)
    skills={key:dict(name=value['name'],ability=value['ability_score']['index'].upper()) for key,value in collection('Skills').items()}
    return dict(abilities=ABILITIES,races={key:dict(value,id=RACE_IDS[key]) for key,value in RACES.items()},classes=classes,backgrounds=BACKGROUNDS,skills=skills)

def build(data):
    name = data.get('name', '').strip()
    if not re.fullmatch(r'[A-Za-z]{3,}(?: [A-Za-z]+)*', name) or len(name) > 24:
        raise ValueError('Nome: 3 a 24 letras, com espaços entre palavras.')
    race, cls, bg = data.get('race'), data.get('class'), data.get('background')
    if race not in RACES or cls not in CLASSES or bg not in BACKGROUNDS:
        raise ValueError('Raça, classe ou antecedente inválido.')
    sex = data.get('sex')
    if type(sex) is not int or sex not in (0,1): raise ValueError('Aparência inválida.')
    base = data.get('scores')
    if not isinstance(base, list) or len(base) != 6 or any(type(n) is not int or n not in COSTS for n in base):
        raise ValueError('Informe seis atributos inteiros de 8 a 15.')
    method = data.get('method')
    if method == 'standard-array':
        if sorted(base) != [8,10,12,13,14,15]: raise ValueError('Distribua 15, 14, 13, 12, 10 e 8 uma vez cada.')
    elif method == 'point-buy':
        if sum(COSTS[n] for n in base) > 27: raise ValueError('Compra de pontos excede 27.')
    else: raise ValueError('Método de atributos inválido.')
    r, c = RACES[race], CLASSES[cls]
    racial_abilities=data.get('racial_abilities',['CON','DEX'] if race=='half-elf' else [])
    racial_skills=data.get('racial_skills',['perception','stealth'] if race=='half-elf' else [])
    ancestry=data.get('ancestry','red' if race=='dragonborn' else None)
    if not isinstance(racial_abilities,list)or not isinstance(racial_skills,list):raise ValueError('Escolhas raciais invalidas.')
    if race=='half-elf':
        if not isinstance(racial_abilities,list) or len(racial_abilities)!=2 or any(type(a) is not str or a not in ABILITIES or a=='CHA' for a in racial_abilities) or len(set(racial_abilities))!=2:raise ValueError('Meio-Elfo: escolha dois atributos diferentes de Carisma.')
        if not isinstance(racial_skills,list) or len(racial_skills)!=2 or any(type(x) is not str or x not in collection('Skills') for x in racial_skills) or len(set(racial_skills))!=2:raise ValueError('Meio-Elfo: escolha duas pericias diferentes.')
    elif racial_abilities or racial_skills:raise ValueError('Esta raca nao permite essas escolhas adicionais.')
    if race=='dragonborn' and ancestry not in r['ancestries']:raise ValueError('Escolha uma ancestralidade draconica valida.')
    if race!='dragonborn' and ancestry is not None:raise ValueError('Ancestralidade draconica exige Draconato.')
    scores = dict(zip(ABILITIES, [a+b for a,b in zip(base,r['bonuses'])]))
    for ability in racial_abilities:scores[ability]+=1
    mods = {a:(n-10)//2 for a,n in scores.items()}
    hp = c['hit_die']+mods['CON']+(race == 'dwarf')+(cls=='sorcerer')
    ac = 16+2+(cls == 'fighter') if c['armor']=='chain' else (11 if c['armor']=='leather' else 10)+mods['DEX']
    if cls=='barbarian':ac=10+mods['DEX']+mods['CON']
    if cls=='monk':ac=10+mods['DEX']+mods['WIS']
    if cls=='druid':ac+=2
    if cls=='ranger':ac=14+min(2,mods['DEX'])
    if cls=='sorcerer':ac=13+mods['DEX']
    explicit_skills='skill_choices' in data
    expertise=['Stealth','Sleight of Hand'] if cls=='rogue' else []
    if explicit_skills:
        selected=validate_class_skills(cls,data['skill_choices'])
        labels=[collection('Skills')[key]['name'] for key in selected]
        fixed=BACKGROUNDS[bg]['skills']+(['Perception'] if race=='elf' else [])+r.get('skills',[])+[collection('Skills')[key]['name'] for key in racial_skills]
        trained=set(labels+fixed)
        duplicates=len(labels+fixed)-len(trained)
        replacements=data.get('proficiency_replacements',[])
        if not isinstance(replacements,list) or any(type(x) is not str for x in replacements) or len(replacements)!=duplicates or len(set(replacements))!=duplicates:
            raise ValueError(f'Escolha {duplicates} substituicao(oes) para proficiencias repetidas.')
        for key in replacements:
            if key not in collection('Skills') or collection('Skills')[key]['name'] in trained:raise ValueError('A substituicao deve ser uma pericia que voce ainda nao conhece.')
            trained.add(collection('Skills')[key]['name'])
        skills=sorted(trained)
        choices=data.get('expertise_choices',[])
        if not isinstance(choices,list) or any(type(x) is not str for x in choices) or len(set(choices))!=len(choices):raise ValueError('Especializacoes invalidas.')
        if cls=='rogue':
            if len(choices)!=2:raise ValueError('Escolha duas especializacoes do Ladino.')
            expertise=[]
            for key in choices:
                label="Thieves' Tools" if key=='thieves-tools' else collection('Skills').get(key,{}).get('name')
                if label!="Thieves' Tools" and label not in trained:raise ValueError('Especializacao exige proficiencia na pericia.')
                expertise.append(label)
        elif choices:raise ValueError('Esta classe ainda nao concede Especializacao.')
    else:
        skills = sorted(set(c['skills']+BACKGROUNDS[bg]['skills']+(['Perception'] if race=='elf' else [])+r.get('skills',[])+[collection('Skills')[key]['name'] for key in racial_skills]))
    skill_bonuses = {}
    for skill, ability in SKILL_ABILITIES.items():
        label = skill.replace('_',' ')
        skill_bonuses[label] = mods[ability]+(4 if label in expertise else 2 if label in skills else 0)
    spell = c['spell']
    colors=data.get('colors',dict(head=78,body=69,legs=58,feet=76))
    if not isinstance(colors,dict) or set(colors)!={'head','body','legs','feet'} or any(type(n) is not int or not 0<=n<=132 for n in colors.values()):
        raise ValueError('Escolha cores de aparência válidas.')
    features=list(c['features'])
    if explicit_skills and cls=='rogue':
        features=[feature for feature in features if not feature.startswith('Especialização:')]
        features.append('Especialização: '+', '.join(expertise))
    spellcasting=bool(spell)and cls not in ('paladin','ranger')
    appearance={'fighter':131,'rogue':129,'cleric':130,'wizard':130,'barbarian':143,'monk':129,'paladin':131,'bard':132,'druid':144,'ranger':129,'sorcerer':130,'warlock':130}
    female={'fighter':139,'rogue':137,'cleric':138,'wizard':138,'barbarian':147,'monk':137,'paladin':139,'bard':140,'druid':148,'ranger':137,'sorcerer':138,'warlock':138}
    return dict(version=2 if explicit_skills else 1, name=name, race=race, **{'class':cls}, background=bg, sex=sex,
        racial_abilities=racial_abilities,racial_skills=racial_skills,ancestry=ancestry,
        level=1, xp=0, proficiency=2, base_scores=base, method=method, scores=scores, modifiers=mods,
        hp=hp, ac=ac, initiative=mods['DEX'], speed=r['speed'],
        saves={a:mods[a]+(2 if a in c['saves'] else 0) for a in ABILITIES},
        skills=skill_bonuses,skill_proficiencies=skills,expertise=expertise,equipment=c['equipment'],traits=r['traits'],features=features,
        spell_ability=spell, spell_dc=8+2+mods[spell] if spellcasting else None,
        spell_attack=2+mods[spell] if spellcasting else None, slots=[1 if cls=='warlock' else 2] if spellcasting else [],
        prepared_limit=max(1,1+mods[spell]) if cls in ('cleric','wizard','druid') else 0,
        colors=colors,looktype=appearance[cls] if sex else female[cls])
