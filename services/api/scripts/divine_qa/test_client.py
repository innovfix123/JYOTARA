import unittest
from client import Client,issues
class Validation(unittest.TestCase):
 def test_grounding_ok_is_not_completion(self):
  self.assertIn('unfinished ending',issues({'answer':'The strongest marriage window I can identify','grounding':'ok'},'English'))
 def test_script_mismatch(self):
  self.assertIn('Tanglish script mismatch',issues({'answer':'Guru dasai-வும் irukku.'},'Tanglish'))
 def test_tamil_valid(self):self.assertEqual([],issues({'answer':'தற்போது குரு தசை நடக்கிறது.'},'Tamil'))
 def test_repair_is_bounded_and_accounted(self):
  calls=[]
  def send(p):calls.append(dict(p));return {'answer':'Unfinished','credits_charged':30}
  r=Client('test',send).ask('s','u','Question?','English',{'full_name':'QA'})
  self.assertIsNone(r['answer']);self.assertEqual(2,len(calls));self.assertNotIn('full_name',calls[1]);self.assertEqual(60,sum(a['reply']['credits_charged'] for a in r['attempts']))
 def test_transport_does_not_retry(self):
  calls=[]
  def send(p):calls.append(p);raise RuntimeError('timeout')
  with self.assertRaises(RuntimeError):Client('test',send).ask('s','u','Q','English')
  self.assertEqual(1,len(calls))
 def test_complete_answer_passes_once(self):
  calls=[]
  def send(p):calls.append(p);return {'answer':'Please tell me whether you are still in contact.'}
  self.assertIsNotNone(Client('test',send).ask('s','u','Q','English')['answer']);self.assertEqual(1,len(calls))
if __name__=='__main__':unittest.main()
