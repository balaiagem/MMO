import unittest
from rules.creation import build, CLASSES, RACES, catalog

def request(cls='fighter',race='human'):
    return dict(name='Test Hero',race=race,**{'class':cls},background='acolyte',sex=1,method='standard-array',scores=CLASSES[cls]['array'])

class CreationTests(unittest.TestCase):
    def test_all_combinations(self):
        for cls in CLASSES:
            for race in RACES:
                p=build(request(cls,race))
                self.assertEqual(p['level'],1)
                self.assertEqual(p['hp'],CLASSES[cls]['hit_die']+p['modifiers']['CON']+(race=='dwarf'))
                self.assertEqual(p['slots'],[2] if cls in ('wizard','cleric') else [])
    def test_reference_profiles(self):
        p=build(request())
        self.assertEqual(p['hp'],12);self.assertEqual(p['ac'],19)
        p=build(request('wizard','elf'))
        self.assertEqual(p['spell_dc'],13);self.assertEqual(p['spell_attack'],5)
        self.assertEqual(p['scores']['INT'],16);self.assertEqual(p['ac'],13)
        self.assertEqual(build(request('fighter','dwarf'))['hp'],14)
        self.assertEqual(build(request('barbarian'))['ac'],14)
        self.assertEqual(build(request('monk'))['ac'],15)
        self.assertEqual(catalog()['classes']['monk']['id'],8)
        self.assertEqual(catalog()['classes']['paladin']['id'],9)
        self.assertEqual(catalog()['races']['half-orc']['id'],8)
        p=build(request('paladin','half-orc'))
        self.assertEqual(p['ac'],18)
        self.assertEqual(p['slots'],[])
        self.assertIn('Intimidation',p['skill_proficiencies'])
    def test_invalid_arrays_and_injection(self):
        for change in [dict(scores=[15]*6),dict(scores=[True,14,13,12,10,8]),dict(name="Hero'); DROP TABLE players;--"),dict(race='dragon'),dict(sex=3),dict(method='client-roll')]:
            with self.assertRaises(ValueError):build(dict(request(),**change))
    def test_point_buy(self):
        p=dict(request(),method='point-buy',scores=[15,15,15,8,8,8])
        self.assertEqual(build(p)['base_scores'],p['scores'])
        with self.assertRaises(ValueError):build(dict(p,scores=[15]*6))
    def test_client_derived_stats_are_ignored(self):
        self.assertEqual(build(dict(request(),hp=999,ac=999,level=20))['hp'],12)

    def test_outfit_colors_are_validated(self):
        colors=dict(head=0,body=132,legs=58,feet=76)
        self.assertEqual(build(dict(request(),colors=colors))['colors'],colors)
        for value in [dict(colors,head=-1),dict(colors,head=133),dict(colors,head=True),{},[]]:
            with self.assertRaises(ValueError):build(dict(request(),colors=value))

    def test_selected_expertise_changes_bonus(self):
        p=build(dict(request('rogue'),skill_choices=['athletics','acrobatics','stealth','investigation'],expertise_choices=['athletics','thieves-tools']))
        self.assertEqual(p['version'],2)
        self.assertEqual(p['skills']['Athletics'],p['modifiers']['STR']+4)
        self.assertEqual(p['skills']['Stealth'],p['modifiers']['DEX']+2)
        self.assertIn("Thieves' Tools",p['expertise'])
        self.assertFalse(any('Stealth e Sleight' in f for f in p['features']))

    def test_duplicate_proficiencies_need_replacement(self):
        data=dict(request('cleric'),skill_choices=['medicine','religion'])
        with self.assertRaises(ValueError):build(data)
        p=build(dict(data,proficiency_replacements=['athletics']))
        self.assertEqual(len(p['skill_proficiencies']),4)
        self.assertIn('Athletics',p['skill_proficiencies'])
        for replacement in ['religion','not-a-skill']:
            with self.assertRaises(ValueError):build(dict(data,proficiency_replacements=[replacement]))

    def test_expertise_requires_training_and_class(self):
        data=dict(request('rogue'),skill_choices=['athletics','acrobatics','stealth','investigation'])
        for choices in [['arcana','athletics'],['athletics','athletics'],[],[True,'athletics']]:
            with self.assertRaises(ValueError):build(dict(data,expertise_choices=choices))
        with self.assertRaises(ValueError):build(dict(request(),skill_choices=['athletics','perception'],expertise_choices=['athletics']))

if __name__=='__main__':unittest.main()
