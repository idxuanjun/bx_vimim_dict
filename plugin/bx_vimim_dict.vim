"=============================================================================
"     FileName: bx_vimim_dict.vim
"         Desc: 通过录入编码输出字典对应的信息
"               插件编码参考源自[vimim-wubi](http://code.google.com/p/vimim-wubi)
"       Author: Xuan Jun
"      License: GNU Lesser General Public License
"         Link: http://blog.csdn.net/idxuanjun
"               https://github.com/idxuanjun/bx_vimim_dict
"      Version: 0.0.2
"   LastChange: 2014-04-28 11:59:52
"      History:
"               2014-04-24：程序已初步调试完成，进入试用阶段；
"=============================================================================
" 最多四键输入，<C-N> <C-P> 上下选择中文
" 中英文输入切换：插入模式下使用 CTRL-L
" 中英文标点切换：插入模式下使用 CTRL-\
" 空格输入中文，回车输入原英文字母
"
" 主要功能函数是补全函数 CVimIM_Dict()
" 读取码表及匹配码表由 GetTable() 和 GetMatchFrom 完成
" 然后还有设置 <BS> <Space> <Enter> 行为的 Smart 函数
" 剩下的就是用来切换状态和设置 map 的函数
"
" 标点上字的功能, 涉及 map 及 unmap ,要动三个地方
" 第一个是 MapChinesePunc() 设置中文标点上字.
" 第二个是 UnMapChinesePunc() 设置英文标点上字.
" 第三个是 Exit() unmap 所有的标点要映射.
"
if exists("b:loaded_bx_vimim_dict") || &cp || v:version < 700
    finish
endif
let b:loaded_bx_vimim_dict = 1
scriptencoding utf-8

" 是否使用五笔
if exists('g:bx_im_wubi_used') && g:bx_im_wubi_used
    let g:bx_im_code_fn = 'bx_vimim_wubi.txt'
    let g:bm_im_charfirst = [1, 3477, 5016, 6371, 9569, 11098, 14620, 18428, 19911, 23828, 26116, 28500, 30475, 32402, 34864, 36276, 38711, 42226, 46442, 49453, 53687, 57072, 58912, 62805, 65013]
else
    let g:bx_im_code_fn = 'bx_vimim_xiaohe.txt'
    let g:bm_im_charfirst = [12, 525, 3164, 4305, 7039, 7395, 8945, 11224, 13796, 15856, 18618, 20099, 22618, 24574, 25849, 25922, 27358, 29211, 30292, 31529, 33781, 36378, 38819, 40376, 42911, 46104]
endif

let s:path = expand("<sfile>:p:h") . "/"
inoremap<silent><expr> <C-L> <SID>Toggle()

function CVimIM_Dict(findstart, keyboard)
    "补全函数
    "首先必须要返回一个起始点, 从超始点到当前光标处, 即是需要
    "匹配的字符.
    "返回的结果, 会替换从起始点到当前光标处的字符.
if a:findstart
    "主要通过 s:typeLen 来控制 <BS> <Enter> <Space> 这些键的行为
    "s:typeLen 在 Init() 中定义.
    "因为最多只能输入4码, 所以在输入的过程中, <BS>等这些键的
    "行为不是不变的.
    "let position = getpos('.')
    let columnNum = col('.') - 1
    let start = columnNum - s:typeLen
    return start
else
    "读取码表的操作在 Init() 函数中,
    "匹配码表的操作在 AnyKey() 函数中.
    if s:matchFrom < 0
        return ''
    else
        "有匹配的情况下, 做扩展的预匹配
        "扩展匹配的一个标准是, 词条平均为9条, 即再扩展8条词条
        let res = []
        let tableLen = len(g:bx_im_table)
        if s:typeLen < 2
            "1码的情况, 直接扩展到2码, 直接往后多匹配5条
            for i in range(5)
                if s:matchFrom + i < tableLen
                    let res = extend(res, split(g:bx_im_table[s:matchFrom + i])[1:])
                endif
            endfor
        elseif s:typeLen < 3
            "2码情况, 直接扩展到3码, 直接往后多匹配6条
            for i in range(6)
                if s:matchFrom + i < tableLen
                    let res = extend(res, split(g:bx_im_table[s:matchFrom + i])[1:])
                endif
            endfor
        elseif s:typeLen < 4
            "3码的情况复杂一点, 最多往后多匹配6条,
            "如果6条内同前3码的匹配不足, 则直接返回.
            for i in range(6)
                if s:matchFrom + i < tableLen
                    let nowLine = g:bx_im_table[s:matchFrom + i]
                    let res = extend(res, split(nowLine)[1:])
                    if s:matchFrom + i + 1 >= tableLen || g:bx_im_table[s:matchFrom + i + 1][:2] != nowLine[:2]
                        break
                    endif
                endif
            endfor
        elseif s:typeLen < 5
            "4码的情况不用扩展
            let res = extend(res, split(g:bx_im_table[s:matchFrom])[1:])
        endif
        return res
    endif
endif
endfunction

function s:GetTable()
    "读取码表
    let tableFile = s:path . g:bx_im_code_fn
    try
        let table = readfile(tableFile)
    catch /E484:/
        echo 'Counld not open the table file `' . tableFile . '`'
    endtry
    return table
endfunction

function s:GetMatchFrom(keyboard)
    "把参数 keyboard 拿到 g:bx_im_table 去匹配，返回字典内的行
    let patterns = '^' . a:keyboard
    let bm_im_charfirstIndex = char2nr(a:keyboard[0]) - 97
    let keyboardLen = len(a:keyboard)

    if keyboardLen < 1
        return -1
    elseif keyboardLen < 2
        "1码直接取存好的各字母起始行
        return g:bm_im_charfirst[bm_im_charfirstIndex]-1
    elseif keyboardLen < 3
        "2码从头字母的起始行开始匹配
        return match(g:bx_im_table, patterns, g:bm_im_charfirst[bm_im_charfirstIndex]-1)
    elseif keyboardLen < 4
        "3码从上一个匹配行(2码或4码)开始匹配.
        if s:matchFrom > 0
            "从2码过来的话, 直接用2码的结果
            return match(g:bx_im_table, patterns, s:matchFrom)
        else
            "用<BS>从4码过来的话, 只能重新查了.
            return match(g:bx_im_table, patterns, g:bm_im_charfirst[bm_im_charfirstIndex] - 1)
        endif
    elseif keyboardLen < 5
        "4码从上一个匹配行(3码)开始匹配, 如果3码没有匹配直接返回-1
        if s:matchFrom < 0
            return -1
        else
            return match(g:bx_im_table, patterns, s:matchFrom)
    endif
endfunction

function s:MapAnyKeys()
    inoremap<buffer><silent> a a<C-R>=<SID>AnyKey('a')<CR>
    inoremap<buffer><silent> b b<C-R>=<SID>AnyKey('b')<CR>
    inoremap<buffer><silent> c c<C-R>=<SID>AnyKey('c')<CR>
    inoremap<buffer><silent> d d<C-R>=<SID>AnyKey('d')<CR>
    inoremap<buffer><silent> e e<C-R>=<SID>AnyKey('e')<CR>
    inoremap<buffer><silent> f f<C-R>=<SID>AnyKey('f')<CR>
    inoremap<buffer><silent> g g<C-R>=<SID>AnyKey('g')<CR>
    inoremap<buffer><silent> h h<C-R>=<SID>AnyKey('h')<CR>
    inoremap<buffer><silent> i i<C-R>=<SID>AnyKey('i')<CR>
    inoremap<buffer><silent> j j<C-R>=<SID>AnyKey('j')<CR>
    inoremap<buffer><silent> k k<C-R>=<SID>AnyKey('k')<CR>
    inoremap<buffer><silent> l l<C-R>=<SID>AnyKey('l')<CR>
    inoremap<buffer><silent> m m<C-R>=<SID>AnyKey('m')<CR>
    inoremap<buffer><silent> n n<C-R>=<SID>AnyKey('n')<CR>
    inoremap<buffer><silent> o o<C-R>=<SID>AnyKey('o')<CR>
    inoremap<buffer><silent> p p<C-R>=<SID>AnyKey('p')<CR>
    inoremap<buffer><silent> q q<C-R>=<SID>AnyKey('q')<CR>
    inoremap<buffer><silent> r r<C-R>=<SID>AnyKey('r')<CR>
    inoremap<buffer><silent> s s<C-R>=<SID>AnyKey('s')<CR>
    inoremap<buffer><silent> t t<C-R>=<SID>AnyKey('t')<CR>
    inoremap<buffer><silent> u u<C-R>=<SID>AnyKey('u')<CR>
    inoremap<buffer><silent> v v<C-R>=<SID>AnyKey('v')<CR>
    inoremap<buffer><silent> w w<C-R>=<SID>AnyKey('w')<CR>
    inoremap<buffer><silent> x x<C-R>=<SID>AnyKey('x')<CR>
    inoremap<buffer><silent> y y<C-R>=<SID>AnyKey('y')<CR>
    if !exists('g:bx_im_wubi_used') || g:bx_im_wubi_used == 0
        inoremap<buffer><silent> z z<C-R>=<SID>AnyKey('z')<CR>
    endif
endfunction

function s:UnMapAnyKeys()
    iunmap<buffer> a
    iunmap<buffer> b
    iunmap<buffer> c
    iunmap<buffer> d
    iunmap<buffer> e
    iunmap<buffer> f
    iunmap<buffer> g
    iunmap<buffer> h
    iunmap<buffer> i
    iunmap<buffer> j
    iunmap<buffer> k
    iunmap<buffer> l
    iunmap<buffer> m
    iunmap<buffer> n
    iunmap<buffer> o
    iunmap<buffer> p
    iunmap<buffer> q
    iunmap<buffer> r
    iunmap<buffer> s
    iunmap<buffer> t
    iunmap<buffer> u
    iunmap<buffer> v
    iunmap<buffer> w
    iunmap<buffer> x
    iunmap<buffer> y
    if !exists('g:bx_im_wubi_used') || g:bx_im_wubi_used == 0
        iunmap<buffer> z
    endif
endfunction

function <SID>Toggle()
    "切换中英文状态
    if !exists('b:chineseMode')
        let b:chineseMode = 0
    endif
    if b:chineseMode < 1
        call s:Init()
    elseif b:chineseMode > 0
        call s:Exit()
    endif
    "不加空格的话,会出现光标退到第一列的事件(第一次到一个新行,且前面有缩进)
    let WTF = "\<SPACE>\<BS>\<C-O>:redraws\<CR>"
    silent!exe 'silent!return "' . WTF . '"'
endfunction

function s:Init()
    " 初始化函数, 要设置需要的一些变量
    " 在更改环境参数的时候, 先把之前的环境参数备份, 以便在切换到
    " 英文状态时还原.
    " 此函数还会设置相关的 map
    " 备份并重新指定
    " 插入模式补全 CTRL-X CTRL-U 使用的函数
    let b:save_completefunc = &completefunc
    let &l:completefunc = 'CVimIM_Dict'
    " 备份并重新指定
    " 插入模式补全使用的选项
    "      menu 使用弹出菜单来显示可能的补全。只有匹配多于一个且有足够的颜
    "       色时才显示该菜单。|ins-completion-menu|
    "   menuone  即使只有一个匹配，也使用弹出菜单。可用于匹配有附加信息的情
    "       况，例如，它来自的文件。
    "   longest  只插入匹配的最长公共文本。如果显示菜单，用 CTRL-L 来插入更
    "       多的字符。是否忽略大小写取决于补全的类型。缓冲区文本使用
    "       'ignorecase' 选项。
    "   preview  在预览窗口里显示当前选择的补全的额外信息。只能和 "menu" 或
    "       "menuone" 搭配使用。
    let b:save_completeopt = &completeopt
    let &l:completeopt = 'menuone'
    " 备份并重新指定
    " 插入模式补全使用的选项
    " 插入模式里使用 :lmap 还是输入方法 (IM)。合法的值是:
    "         0 :lmap 关闭而 IM 关闭
    "         1 :lmap 打开而 IM 关闭
    "         2 :lmap 关闭而 IM 打开
    let b:save_iminsert = &iminsert
    let &l:iminsert = 1
    " 备份并重新指定
    " 决定用于插入模式补全的弹出菜单显示项目的最大数目。
    " 如果为零，有多少空间就用多少。
    let b:save_pumheight = &pumheight
    let &l:pumheight = 9
    highlight! lCursor guifg=bg guibg=green
    " === 下面的我不懂什么意思啊
    " 备份并重新指定
    " 单字符标志位的序列。每个字符的存在指示一种 vi 兼容的行为。
    " 可用于改变常见或被认为是更好的 vi 不兼容的行为。
    let b:save_cpo = &cpo
    set cpo&vim
    " 备份并重新指定
    " 执行宏、寄存器和其它不通过输入的命令时屏幕会不会重画。
    " 另外，窗口标题的刷新是否也被推迟。
    let b:save_lazyredraw = &lazyredraw
    set nolazyredraw
    " 备份并重新指定
    " 将 Vim 切换到粘贴模式。可用于从一个窗口剪切或复制文本并粘贴到 Vim。
    " 它的使用会避免一些意想不到的效果。
    let b:save_paste = &paste
    set nopaste
    " ==========
    if !exists('g:bx_im_table')
        let g:bx_im_table = s:GetTable()
    endif
    if !exists('b:chinesePunc')
        " 标点的状态要在中英文间保持
         let b:chinesePunc = 1
        "let b:chinesePunc = 0
    endif
    if b:chinesePunc > 0
        call s:MapChinesePunc()
    else
        call s:UnMapChinesePunc()
    endif
    let s:typeLen = 0
    let b:chineseMode = 1
    call s:MapAnyKeys()
    " map 一些特殊的键
    inoremap<buffer> <Space> <C-R>=<SID>SmartSpace()<CR>
    inoremap<buffer> <BS> <C-R>=<SID>SmartBack()<CR>
    inoremap<buffer> <CR> <C-R>=<SID>SmartEnter()<CR>
    inoremap<buffer> <C-\> <C-R>=<SID>ToggleChinesePunc()<CR>
    inoremap<buffer> <ESC> <C-R>=<SID>RZ()<CR><ESC>
    inoremap<buffer> <C-W> <C-R>=<SID>RZ()<CR><C-W>
    " 设置弹出菜单的彩色
    highlight! link PmenuSel MatchParen
    highlight! link Pmenu StatusLine
    " highlight! PmenuSbar    NONE
    highlight! link PmenuThumb DiffAdd
    return ''
endfunction

function s:Exit()
    " 退出中文输入状态调用此函数,
    " 它会还原以前的环境变量, 同时把一些变量设置成默认,
    " 它还会 unmap 一些映射.
    " 还原环境变量设置
    let &l:completeopt = b:save_completeopt
    let &l:completefunc = b:save_completefunc
    let &l:iminsert = b:save_iminsert
    let &l:pumheight = b:save_pumheight
    let &l:cpo = b:save_cpo
    let &l:lazyredraw = b:save_lazyredraw
    let &l:paste = b:save_paste
    " 还原光标彩色
    highlight! ICursor None
    " 还原弹出菜单彩色
    highlight! link PmenuSel PmenuSel
    highlight! link Pmenu Pmenu
    "highlight! PmenuSbar     NONE
    highlight! link PmenuThumb PmenuThumb
    " 还原自身的一些变量
    let s:typeLen = 0
    "let b:chinesePunc = 0
    let b:chineseMode = 0
    " 还原 [a-z] 的 map
    call s:UnMapAnyKeys()
    " 还原特殊键的 map
    iunmap<buffer> <Space>
    iunmap<buffer> <BS>
    iunmap<buffer> <CR>
    iunmap<buffer> <C-\>
    iunmap<buffer> <ESC>
    iunmap<buffer> <C-W>
    " 还原标点的 map
    iunmap<buffer> ,
    iunmap<buffer> .
    iunmap<buffer> ;
    iunmap<buffer> :
    iunmap<buffer> ?
    iunmap<buffer> \
    iunmap<buffer> /
    iunmap<buffer> !
    iunmap<buffer> @
    iunmap<buffer> ^
    iunmap<buffer> _
    iunmap<buffer> #
    iunmap<buffer> %
    iunmap<buffer> $
    iunmap<buffer> `
    iunmap<buffer> ~
    iunmap<buffer> {
    iunmap<buffer> }
    iunmap<buffer> <
    iunmap<buffer> >
    iunmap<buffer> (
    iunmap<buffer> )
    iunmap<buffer> '
    iunmap<buffer> "
    return ''
endfunction

function <SID>AnyKey(key)
    "[a-z]在输入过程中的行为
    let s:typeLen += 1
    if s:typeLen > 1
        "考虑在按了 <C-N> <C-P> 后继续输入的情况
        "如果前一个字符是中文, 则无法再继续匹配, 处理这种情况.
        let columnNum = col('.')
        let charBefore = getline('.')[columnNum - 3]
        if charBefore !~# '\l'
            "虽然 \L 中有一个`z`, 但这不会有什么问题
            let s:typeLen = 1
            call s:RefreshMatch()
            let temp = "\<C-Y>\<C-X>\<C-U>\<C-P>\<Down>"
        endif
        silent!exe 'silent!return "' . temp . '"'
    endif
    if s:typeLen == 5
        "限制4码输入在这里实现.
        "要考虑前4码是否有匹配两种情况.
        let p = getpos('.')
        call setpos('.', [p[0], p[1], p[2] - 1, p[3]])
        let s:typeLen -= 1
        call s:RefreshMatch()
        "前4码肯定有匹配, 则先保存前4码的第一个匹配, 用这个匹配去
        "代替前4码, 再重新匹配第5码
        let word = split(g:bx_im_table[s:matchFrom])[1]
        "这里不能是四个<BS>, 不知道为什么!
        let temp = "\<Left>\<Del>\<BS>\<BS>\<BS>" . word . "\<Right>\<C-X>\<C-U>\<C-P>\<Down>"
        let s:matchFrom = s:GetMatchFrom(a:key)
        let s:typeLen = 1
        silent!exe 'silent!return "' . temp . '"'
    endif
    call s:RefreshMatch()
    if s:matchFrom < 0
        "不能匹配的情况, 只可能出现在3码或4码
        "是否要实现如果3码无匹配则不能输入4码呢?
        "TODO: 3码无匹配则不能输入4码, 或无匹配自动删除.
        let temp = "\<Del>\<C-X>\<C-U>\<C-P>\<Down>"
        let s:typeLen -= 1
        "要重新定位光标才正确取码
        let p = getpos('.')
        call setpos('.', [p[0], p[1], p[2] - 1, p[3]])
        call s:RefreshMatch()
    else
        let temp = "\<C-X>\<C-U>\<C-P>\<Down>"
    endif
    silent!exe 'silent!return "' . temp . '"'
endfunction

function s:RefreshMatch()
    "刷新匹配列表.
    "在更新计数器 s:typeLen 时注意考虑是否要调用.
    "考虑 <Space> <BS> <Enter> 这些行为时考虑是否要调用.
    "let position = getpos('.')
    let lineNum = line('.')
    let columnNum = col('.') - 1
    let temstr = getline(lineNum)
    let from = columnNum - s:typeLen
    let to = columnNum - 1
    let s:matchFrom = s:GetMatchFrom(temstr[from : to])
endfunction

function <SID>SmartSpace()
    "<Space>在输入过程中的行为
    let space = ' '
    if pumvisible()
        let space = "\<C-Y>"
    elseif s:typeLen == 1
        let space = "\<BS>"
    elseif s:typeLen == 2
        let space = "\<BS>\<BS>"
    elseif s:typeLen == 3
        let space = "\<BS>\<BS>\<BS>"
    elseif s:typeLen == 4
        let space = "\<BS>\<BS>\<BS>\<BS>"
    endif
    let s:typeLen = 0
    silent!exe 'silent!return "' . space . '"'
endfunction

function <SID>SmartEnter()
    "<Enter>在输入过程中的行为
    if pumvisible()
        "如果有匹配列表, 则上屏第一个匹配
        let enter = "\<C-E>"
        "如果没有匹配列表, 则删除已经输入的废码
        "现在不可能出现没有匹配的情况了
    else
        "完全没事干了, 再换行吧
        let enter = "\<CR>"
    endif
    let s:typeLen = 0
    silent!exe 'silent!return "' . enter . '"'
endfunction

function <SID>SmartBack()
    "<Backspace>在输入过程中的行为
    let bs = "\<BS>"
    if s:typeLen > 1
        "只有1码时, 不要 <BS> '自作聪明'
        let s:typeLen -= 1
        "s:typeLen 变了, 要重新定位光标并刷新匹配结果
        let p = getpos('.')
        "存在按了 <C-N> <C-P> 后, <BS> 是删除一个中文字的情况,
        "这种情况如果执行 s:RefreshMatch() 会出现越界错误,
        "因为它前面的字符是一个中文字, 无法拿去匹配码表的.
        if getline('.')[p[2] - 3] !~# '\l'
            let s:typeLen = 0
            let s:matchFrom = -1
            let bs = bs . "\<C-X>\<C-U>"
        else
            call setpos('.', [p[0], p[1], p[2] - 1, p[3]])
            call s:RefreshMatch()
            let bs = "\<Del>\<C-X>\<C-U>\<C-P>\<Down>"
        endif
    else
        "只可能是 s:typeLen == 0 || s:typeLen == 1
        "不管是哪种, 按了 <BS> 匹配列表都应该清空
        let s:typeLen = 0
        let s:matchFrom = -1
    endif
    silent!exe 'silent!return "' . bs . '"'
endfunction

function s:MapChinesePunc()
    "映射中文标点
    let b:chinesePunc = 1
    inoremap<buffer> , <C-R>=<SID>PuncIn()<CR>，
    inoremap<buffer> . <C-R>=<SID>PuncIn()<CR>。
    inoremap<buffer> ; <C-R>=<SID>PuncIn()<CR>；
    inoremap<buffer> : <C-R>=<SID>PuncIn()<CR>：
    inoremap<buffer> ? <C-R>=<SID>PuncIn()<CR>？
    inoremap<buffer> \ <C-R>=<SID>PuncIn()<CR>、
    inoremap<buffer> / <C-R>=<SID>PuncIn()<CR>/
    inoremap<buffer> ! <C-R>=<SID>PuncIn()<CR>！
    inoremap<buffer> @ <C-R>=<SID>PuncIn()<CR>・
    inoremap<buffer> ^ <C-R>=<SID>PuncIn()<CR>……
    inoremap<buffer> _ <C-R>=<SID>PuncIn()<CR>——
    inoremap<buffer> # <C-R>=<SID>PuncIn()<CR>＃
    inoremap<buffer> % <C-R>=<SID>PuncIn()<CR>％
    inoremap<buffer> $ <C-R>=<SID>PuncIn()<CR>￥
    inoremap<buffer> ` <C-R>=<SID>PuncIn()<CR>`
    inoremap<buffer> ~ <C-R>=<SID>PuncIn()<CR>～
    inoremap<buffer> < <C-R>=<SID>PuncIn()<CR>《
    inoremap<buffer> > <C-R>=<SID>PuncIn()<CR>》
    inoremap<buffer> ( <C-R>=<SID>PuncIn()<CR>（
    inoremap<buffer> ) <C-R>=<SID>PuncIn()<CR>）
    inoremap<buffer> { <C-R>=<SID>PuncIn()<CR>『
    inoremap<buffer> } <C-R>=<SID>PuncIn()<CR>』
    inoremap<buffer> ' <C-R>=<SID>PuncIn()<CR><C-R>=<SID>ToggleChineseQuote("'")<CR>
    inoremap<buffer> " <C-R>=<SID>PuncIn()<CR><C-R>=<SID>ToggleChineseQuote('"')<CR>
endfunction

function s:UnMapChinesePunc()
    " 解除映射中文标点
    let b:chinesePunc = 0
    inoremap<buffer> , <C-R>=<SID>PuncIn()<CR>,
    inoremap<buffer> . <C-R>=<SID>PuncIn()<CR>.
    inoremap<buffer> ; <C-R>=<SID>PuncIn()<CR>;
    inoremap<buffer> : <C-R>=<SID>PuncIn()<CR>:
    inoremap<buffer> ? <C-R>=<SID>PuncIn()<CR>?
    inoremap<buffer> \ <C-R>=<SID>PuncIn()<CR>\
    inoremap<buffer> / <C-R>=<SID>PuncIn()<CR>/
    inoremap<buffer> ! <C-R>=<SID>PuncIn()<CR>!
    inoremap<buffer> @ <C-R>=<SID>PuncIn()<CR>@
    inoremap<buffer> ^ <C-R>=<SID>PuncIn()<CR>^
    inoremap<buffer> _ <C-R>=<SID>PuncIn()<CR>_
    inoremap<buffer> # <C-R>=<SID>PuncIn()<CR>#
    inoremap<buffer> % <C-R>=<SID>PuncIn()<CR>%
    inoremap<buffer> $ <C-R>=<SID>PuncIn()<CR>$
    inoremap<buffer> ` <C-R>=<SID>PuncIn()<CR>`
    inoremap<buffer> ~ <C-R>=<SID>PuncIn()<CR>~
    inoremap<buffer> < <C-R>=<SID>PuncIn()<CR><
    inoremap<buffer> > <C-R>=<SID>PuncIn()<CR>>
    inoremap<buffer> ( <C-R>=<SID>PuncIn()<CR>(
    inoremap<buffer> ) <C-R>=<SID>PuncIn()<CR>)
    inoremap<buffer> { <C-R>=<SID>PuncIn()<CR>{
    inoremap<buffer> } <C-R>=<SID>PuncIn()<CR>}
    inoremap<buffer> ' <C-R>=<SID>PuncIn()<CR>'
    inoremap<buffer> " <C-R>=<SID>PuncIn()<CR>"
endfunction

function <SID>ToggleChinesePunc()
    "中英文标点状态的切换
    if b:chinesePunc > 0
        call s:UnMapChinesePunc()
    else
        call s:MapChinesePunc()
    endif
    return ''
endfunction

function <SID>ToggleChineseQuote(mark)
    " 中文引号成对切换
    if a:mark == "'"
        if !exists('b:singleMode')
            let b:singleMode = 0
        endif
        let b:singleMode = abs(b:singleMode - 1)
        return b:singleMode == 1 ? "‘" : "’"
    elseif a:mark == '"'
        if !exists('b:doubleMode')
            let b:doubleMode = 0
        endif
        let b:doubleMode = abs(b:doubleMode - 1)
        return b:doubleMode == 1 ? "“" : "”"
    endif
endfunction

function s:WTF()
    " ...
    let WTF = "\<ESC>a"
    silent!exe 'silent!return "' . WTF . '"'
endfunction

function <SID>PuncIn()
    let s:typeLen = 0
    if pumvisible()
        let puncIn = "\<C-Y>"
    else
        let puncIn = ''
    endif
    silent!exe 'silent!return "' . puncIn . '"'
endfunction

function <SID>RZ()
    let s:typeLen = 0
    let s:matchFrom = -1
    return ''
endfunction

function s:Debug(var)
    let a = inputdialog(a:var)
endfunction
