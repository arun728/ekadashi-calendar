import os
from pathlib import Path
import subprocess
root=Path(os.environ.get('PANCHANG_AUDIT_WORKDIR', '/workspace/panchang-audit')) / 'kotlin';repo=Path(os.environ.get('PANCHANG_REPO', '/workspace/ekadashi-calendar'))
base='android/app/src/main/kotlin/com/applausestudios/ekadashi_calendar/widget/model/'
test=(repo/'android/app/src/test/kotlin/com/applausestudios/ekadashi_calendar/AfterOnlyParanaTest.kt').read_text()
test='\n'.join(x for x in test.splitlines() if 'robolectric' not in x.lower() and '@RunWith' not in x and '@Config' not in x)
cp=':'.join(str(p) for p in root.glob('*.jar'))
for mode in ['before','after']:
 folder=root/mode;folder.mkdir(exist_ok=True)
 for name in ['WidgetData.kt','WidgetTimeline.kt']:
  contents=subprocess.check_output(['git','show','c15bce7:'+base+name],cwd=repo,text=True) if mode=='before' else (repo/base/name).read_text()
  (folder/name).write_text(contents)
 (folder/'AfterOnlyParanaTest.kt').write_text(test)
 with (root/f'{mode}.log').open('w') as log:
  cmd=['java','-cp',cp,'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-no-stdlib','-no-reflect','-jvm-target','17','-classpath',cp,'-d',str(folder/'classes')]+[str(p) for p in folder.glob('*.kt')]
  r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT)
  if r.returncode:print(mode,'compile failure');continue
  r=subprocess.run(['java','-cp',str(folder/'classes')+':'+cp,'org.junit.runner.JUnitCore','com.applausestudios.ekadashi_calendar.AfterOnlyParanaTest'],stdout=log,stderr=subprocess.STDOUT)
  print(mode,'exit',r.returncode)
