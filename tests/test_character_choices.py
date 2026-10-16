import unittest
from rules.catalog2014 import collection
from rules.choices import resolve,starting_equipment,class_skill_options,skills

def first_choice(choice):
    source=choice['from']
    if source['option_set_type']=='equipment_category':
        item=collection('Equipment-Categories')[source['equipment_category']['index']]['equipment'][0]['index']
        return [{'item':item} for _ in range(choice['choose'])]
    return [{'option':i,'children':first_option(source['options'][i])} for i in range(choice['choose'])]

def first_option(option):
    if option['option_type']=='choice':return first_choice(option['choice'])
    if option['option_type']=='multiple':return [first_option(o) for o in option['items']]
    return None

class Choices(unittest.TestCase):
    def test_every_class_starter_loadout(self):
        for cls in collection('Classes').values():
            selected=[first_choice(c) for c in cls['starting_equipment_options']]
            items=starting_equipment(cls['index'],selected)
            self.assertTrue(items,cls['index'])
            self.assertTrue(all(v>0 for v in items.values()))
            for item in items:self.assertIn(item,collection('Equipment'))
    def test_fighter_loadout_counts_from_server(self):
        c=collection('Classes')['fighter']
        items=starting_equipment('fighter',[first_choice(v) for v in c['starting_equipment_options']])
        self.assertEqual(items['chain-mail'],1)
        self.assertEqual(items['shield'],1)
        self.assertEqual(items['crossbow-bolt'],20)
    def test_equipment_category_rejects_forged_item(self):
        choice={'choose':1,'type':'equipment','from':{'option_set_type':'equipment_category','equipment_category':{'index':'simple-weapons'}}}
        with self.assertRaises(ValueError):resolve(choice,[{'item':'plate-armor'}])
        with self.assertRaises(ValueError):resolve(choice,[{'item':'dagger','count':999}])
        self.assertEqual(resolve(choice,[{'item':'dagger'}])[0]['count'],1)
    def test_nested_set_cannot_omit_shield(self):
        choice=collection('Classes')['fighter']['starting_equipment_options'][1]
        with self.assertRaises(ValueError):resolve(choice,[{'option':0,'children':[None]}])
    def test_skill_choices_for_all_classes(self):
        expected={'fighter':2,'rogue':4,'bard':3,'ranger':3}
        for cls in collection('Classes'):
            count,allowed=class_skill_options(cls)
            self.assertEqual(count,expected.get(cls,2))
            self.assertEqual(skills(cls,allowed[:count]),allowed[:count])
            with self.assertRaises(ValueError):skills(cls,[allowed[0]]*count)
            with self.assertRaises(ValueError):skills(cls,allowed[:count-1])
    def test_noninteger_or_bool_option_rejected(self):
        choice=collection('Classes')['wizard']['starting_equipment_options'][0]
        for value in [True,-1,100,'0',0.0]:
            with self.assertRaises(ValueError):resolve(choice,[{'option':value}])
if __name__=='__main__':unittest.main()
