"""Make extracted controllers own their signal connections and scheduled work."""
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
TOKEN=re.compile(r'--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[A-Za-z_]\w*|\S')

def transform(source):
    tokens=[m for m in TOKEN.finditer(source) if not m[0].startswith('--')]
    def prefix_end(i):
        value=tokens[i][0]
        if value in (')',']'):
            opening={'(':')','[':']'}
            close=value; op='(' if close==')' else '['; depth=1;j=i-1
            while depth:
                if tokens[j][0]==close:depth+=1
                elif tokens[j][0]==op:depth-=1
                j-=1
            return prefix_end(j)
        assert re.fullmatch(r'[A-Za-z_]\w*',value),value
        if i>=2 and tokens[i-1][0] in ('.',':'):return prefix_end(i-2)
        return i
    edits=[]
    for i,m in enumerate(tokens):
        if m[0]=='Connect' and i>1 and tokens[i-1][0]==':' and tokens[i+1][0]=='(':
            start=prefix_end(i-2)
            signal=source[tokens[start].start():tokens[i-1].start()]
            edits.append((tokens[start].start(),tokens[i+1].end(),'Context.connections:connect('+signal+', '))
        if m[0]=='task' and i+3<len(tokens) and tokens[i+1][0]=='.' and tokens[i+2][0] in ('spawn','defer','delay') and tokens[i+3][0]=='(':
            edits.append((m.start(),tokens[i+3].end(),'Context.connections:'+tokens[i+2][0]+'('))
    for a,b,text in sorted(edits,reverse=True):source=source[:a]+text+source[b:]
    return source,len(edits)

if __name__=='__main__':
    total=0
    for name in ['ui/UIController','ui/NotificationController','shop/ShopController','shop/SellController','tutorial/TutorialController']:
        folder=ROOT/'src/client/controllers'/name
        root=folder/'init.luau'
        source=root.read_text(encoding='utf-8')
        source='local Scope = require(game:GetService("ReplicatedStorage").shared.util.ConnectionScope)\n'+source
        source=source.replace('local Context = { State = State,','local Context = { State = State, connections = Scope.new(),')
        api=re.search(r'\nreturn (\w+)',source)[1]
        source=source.replace('\nreturn '+api,'\n'+api+'.clearConnections = function() Context.connections:clear() end\nreturn '+api)
        root.write_text(source,encoding='utf-8')
        for p in folder.rglob('*.luau'):
            if p==root:continue
            source,count=transform(p.read_text(encoding='utf-8'))
            p.write_text(source,encoding='utf-8');total+=count
    print('Scoped',total,'connections/tasks')
