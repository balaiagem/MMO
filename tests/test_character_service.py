import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('character_service_test',Path(__file__).resolve().parents[1]/'tools/character-service.py')
service=importlib.util.module_from_spec(spec);spec.loader.exec_module(service)

class DeletionTests(unittest.TestCase):
    def run_delete(self,change=None,found='42\t0',updated='1'):
        calls=[]
        def sql(query):
            calls.append(query)
            if query.startswith('SELECT id FROM accounts'):return '100'
            if query.startswith('SELECT p.id'):return found
            if query.startswith('UPDATE players p'):return updated
            return ''
        data=dict(account='owner',password='secret',name='My Hero',confirmation='My Hero')
        data.update(change or {})
        with patch.object(service,'sql',sql):result=service.handle('delete',data)
        return result,calls

    def test_exact_confirmation_required(self):
        for confirmation in ['',None,'my hero','My Hero ','Someone Else']:
            with self.assertRaisesRegex(ValueError,'nome exato'):self.run_delete(dict(confirmation=confirmation))

    def test_account_ownership_required(self):
        with self.assertRaisesRegex(ValueError,'nesta conta'):self.run_delete(found='')

    def test_online_character_and_raced_login_rejected(self):
        with self.assertRaisesRegex(ValueError,'Desconecte'):self.run_delete(found='42\t1')
        with self.assertRaisesRegex(ValueError,'Atualize'):self.run_delete(updated='0')

    def test_delete_is_guarded_and_preserves_data(self):
        result,calls=self.run_delete()
        self.assertEqual(result,dict(name='My Hero',deleted=True))
        update=next(q for q in calls if q.startswith('UPDATE players p'))
        self.assertIn('p.account_id=100',update)
        self.assertIn('o.player_id IS NULL',update)
        self.assertIn('p.deletion=0',update)
        self.assertFalse(any('DELETE FROM' in q for q in calls))
        lookup=next(q for q in calls if q.startswith('SELECT p.id'))
        self.assertIn('BINARY p.name=BINARY',lookup)

    def test_authentication_required(self):
        with patch.object(service,'sql',return_value=''):
            with self.assertRaisesRegex(ValueError,'Conta ou senha'):service.handle('delete',dict(account='wrong',password='wrong',name='Hero',confirmation='Hero'))

    def test_live_metadata_uses_current_storage_not_creation_level(self):
        def sql(query):
            if query.startswith('SELECT id FROM accounts'):return '100'
            if query.startswith('SELECT p.name'):return 'Hero\tNULL\t8\t2\t5\t129\t78\t69\t58\t76\t0\t1'
            return ''
        with patch.object(service,'sql',sql):rows=service.handle('list',dict(account='owner',password='secret'))
        self.assertEqual(rows[0]['level'],5)
        self.assertEqual(rows[0]['class_id'],8)
        self.assertTrue(rows[0]['online'])
        self.assertEqual(rows[0]['outfit']['type'],129)

if __name__=='__main__':unittest.main()
