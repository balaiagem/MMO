"""Validate SRD choice trees. Counts and references always come from the server."""
from collections import Counter
from .catalog2014 import collection

def _object(value,allowed):
    if not isinstance(value,dict) or set(value)-set(allowed):raise ValueError('Formato de escolha invalido.')
    return value

def resolve(choice,selections):
    """Selection: [{option: index, children: ...}] or [{item: equipment_id}]."""
    count=choice['choose']
    if not isinstance(selections,list) or len(selections)!=count:raise ValueError(f'Escolha exatamente {count} opcao(oes).')
    source=choice['from'];kind=source['option_set_type'];result=[]
    if kind=='equipment_category':
        category=collection('Equipment-Categories')[source['equipment_category']['index']]
        allowed={item['index'] for item in category['equipment']}
        for selection in selections:
            _object(selection,{'item'})
            if selection.get('item') not in allowed:raise ValueError('Equipamento fora da categoria permitida.')
            result.append(dict(kind='equipment',index=selection['item'],count=1))
    elif kind=='options_array':
        options=source['options']
        for selection in selections:
            _object(selection,{'option','children'})
            index=selection.get('option')
            if type(index) is not int or not 0<=index<len(options):raise ValueError('Opcao desconhecida.')
            result.extend(_resolve_option(options[index],selection.get('children')))
    elif kind=='resource_list':
        url=source.get('resource_list_url','')
        names={'languages':'Languages','skills':'Skills','proficiencies':'Proficiencies'}
        name=names.get(url.rstrip('/').split('/')[-1])
        if not name:raise ValueError('Lista de escolhas ainda nao suportada: '+url)
        allowed=collection(name)
        for selection in selections:
            _object(selection,{'item'})
            if selection.get('item') not in allowed:raise ValueError('Referencia desconhecida.')
            result.append(dict(kind=name.lower(),index=selection['item'],count=1))
    else:raise ValueError('Tipo de escolha ainda nao suportado: '+kind)
    if choice['type']!='equipment':
        keys=[(entry['kind'],entry['index']) for entry in result]
        if len(keys)!=len(set(keys)):raise ValueError('As escolhas devem ser diferentes.')
    return result

def _resolve_option(option,children):
    kind=option['option_type']
    if kind=='choice':return resolve(option['choice'],children)
    if kind=='multiple':
        if not isinstance(children,list) or len(children)!=len(option['items']):raise ValueError('Selecao de conjunto incompleta.')
        result=[]
        for child,selection in zip(option['items'],children):result.extend(_resolve_option(child,selection))
        return result
    if children is not None:raise ValueError('Esta opcao nao aceita subescolhas.')
    if kind in ('reference','counted_reference'):
        ref=option['item'] if kind=='reference' else option['of']
        return [dict(kind=ref['url'].split('/')[-2],index=ref['index'],count=option.get('count',1))]
    if kind=='ability_bonus':return [dict(kind='ability_bonus',index=option['ability_score']['index'],count=option['bonus'])]
    if kind in ('string','ideal'):return [dict(kind=kind,index=option.get('string',option.get('desc')),count=1)]
    raise ValueError('Opcao ainda nao suportada: '+kind)

def starting_equipment(class_id,selections):
    cls=collection('Classes')[class_id];groups=cls['starting_equipment_options']
    if not isinstance(selections,list) or len(selections)!=len(groups):raise ValueError('Escolha todos os grupos de equipamento inicial.')
    items=Counter({})
    for entry in cls['starting_equipment']:items[entry['equipment']['index']]+=entry['quantity']
    for choice,selection in zip(groups,selections):
        for item in resolve(choice,selection):
            if item['kind']!='equipment':raise ValueError('Referencia de equipamento invalida.')
            items[item['index']]+=item['count']
    return dict(items)

def class_skill_options(class_id):
    cls=collection('Classes')[class_id]
    for choice in cls['proficiency_choices']:
        options=choice['from'].get('options',[])
        if options and all(o['option_type']=='reference' and o['item']['index'].startswith('skill-') for o in options):
            return choice['choose'],[o['item']['index'][6:] for o in options]
    raise ValueError('Classe sem escolhas de pericia conhecidas.')

def skills(class_id,selections):
    count,allowed=class_skill_options(class_id)
    if not isinstance(selections,list) or len(selections)!=count or any(type(v) is not str for v in selections) or len(set(selections))!=count:
        raise ValueError(f'Escolha {count} pericias diferentes da classe.')
    if not set(selections)<=set(allowed):raise ValueError('Pericia nao permitida para esta classe.')
    return list(selections)
