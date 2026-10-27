import sys
lay, text = sys.argv[1], sys.argv[2]
S='KEY_LEFTSHIFT '
us={' ':'KEY_SPACE','-':'KEY_MINUS','_':S+'KEY_MINUS','=':'KEY_EQUAL','+':S+'KEY_EQUAL','/':'KEY_SLASH','?':S+'KEY_SLASH',
 '.':'KEY_DOT','>':S+'KEY_DOT',',':'KEY_COMMA','<':S+'KEY_COMMA',';':'KEY_SEMICOLON',':':S+'KEY_SEMICOLON',"'":'KEY_APOSTROPHE',
 '"':S+'KEY_APOSTROPHE','|':S+'KEY_BACKSLASH','\\':'KEY_BACKSLASH','&':S+'KEY_7','@':S+'KEY_2','~':S+'KEY_GRAVE','*':S+'KEY_8',
 '(':S+'KEY_9',')':S+'KEY_0','$':S+'KEY_4','!':S+'KEY_1','#':S+'KEY_3','\n':'KEY_ENTER'}
de={' ':'KEY_SPACE','-':'KEY_SLASH','_':S+'KEY_SLASH','=':S+'KEY_0','+':'KEY_RIGHTBRACE','/':S+'KEY_7','?':S+'KEY_MINUS',
 '.':'KEY_DOT','>':S+'KEY_102ND',',':'KEY_COMMA','<':'KEY_102ND',';':S+'KEY_COMMA',':':S+'KEY_DOT',"'":S+'KEY_BACKSLASH',
 '"':S+'KEY_2','|':'KEY_RIGHTALT KEY_102ND','\\':'KEY_RIGHTALT KEY_MINUS','&':S+'KEY_6','@':'KEY_RIGHTALT KEY_Q','~':'KEY_RIGHTALT KEY_RIGHTBRACE',
 '*':S+'KEY_RIGHTBRACE','(':S+'KEY_8',')':S+'KEY_9','$':S+'KEY_4','!':S+'KEY_1','#':'KEY_BACKSLASH','\n':'KEY_ENTER'}
m = us if lay=='us' else de
for c in text:
    if lay=='de' and c in 'yzYZ': c={'y':'z','z':'y','Y':'Z','Z':'Y'}[c]
    if c.isalpha() and c.isascii(): print((S if c.isupper() else '')+'KEY_'+c.upper())
    elif c.isdigit(): print('KEY_'+c)
    elif c in m: print(m[c])
    else: sys.exit('nicht unterstützt: '+c)
