import unittest
from rules.catalog2014 import collection,class_level,spell,ability_for_skill
from rules.creation import SKILL_ABILITIES
class SRDCatalog(unittest.TestCase):
    def test_all_class_levels(self):
        self.assertEqual(len(collection('Classes')),12)
        for cls in collection('Classes'):
            for level in range(1,21):
                row=class_level(cls,level)
                self.assertEqual(row['level'],level)
                self.assertEqual(row['prof_bonus'],2+(level-1)//4)
    def test_attributes_and_skills(self):
        self.assertEqual(len(collection('Ability-Scores')),6)
        self.assertEqual(len(SKILL_ABILITIES),18)
        for row in collection('Skills').values():
            key=row['name'].replace(' ','_')
            self.assertEqual(SKILL_ABILITIES[key],ability_for_skill(row['index']))
    def test_spells(self):
        self.assertEqual(len(collection('Spells')),319)
        for row in collection('Spells').values():
            self.assertIn(row['level'],range(10))
            self.assertIsInstance(row['concentration'],bool)
            for cls in row['classes']:self.assertIn(cls['index'],collection('Classes'))
        self.assertEqual(spell('mass-healing-word')['casting_time'],'1 bonus action')
        self.assertEqual(spell('scorching-ray')['level'],2)
    def test_audited_warlock_invocations(self):
        self.assertEqual(class_level('warlock',4)['class_specific']['invocations_known'],2)
        self.assertEqual(class_level('warlock',5)['class_specific']['invocations_known'],3)
        self.assertEqual(collection('Levels')['warlock-4']['class_specific']['invocations_known'],3)
if __name__=='__main__':unittest.main()
