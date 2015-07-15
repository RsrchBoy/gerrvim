" Gerrit review's comments preparation helper
" Maintainer: Sergey Matveev <stargrave@stargrave.org>
" License: GNU General Public License version 3 of the License or later

if exists("g:loaded_gerrvim") | finish | endif
let g:loaded_gerrvim = 1

if !exists("g:gerrvim_file")
    let g:gerrvim_file = "/tmp/gerrvim.txt"
endif

function! s:Gerrvim() range
    let SHA1_LENGTH = 40
    if bufwinnr("GerrvimCommenting") != -1
        echohl ErrorMsg | echomsg "Close already existing code commenting window first" | echohl None
        return
    endif
    if bufexists("GerrvimCommenting") != 0
        bdelete! GerrvimCommenting
    endif
    " Determine file's path inside repository
    let path = expand("%:p")
    let path = substitute(path, fugitive#extract_git_dir(".")[:-5], "", "")
    let path = substitute(path, "^.*\.git//", "", "")
    " Header generation
    let header = []
    if match(path, "/") ==# SHA1_LENGTH
        let header = add(header, path[:SHA1_LENGTH-1])
        let header = add(header, path[SHA1_LENGTH+1:])
    else
        let header = add(header, "")
        let header = add(header, path)
    endif
    let header = add(header, string(a:firstline))
    let header = add(header, string(a:lastline + 1))
    let ready = ["-----BEGIN " . join(header, " ") . "-----"]
    " Collect enumerated selected code block's lines
    for bufline in getline(a:firstline, a:lastline)
        let ready = add(ready, bufline)
    endfor
    let ready = add(ready, "-----END-----")
    " Spawn a new small code commenting window nonbinded to file
    new GerrvimCommenting
    resize 16
    setlocal noswapfile
    setlocal buftype=acwrite
    call append("^", ready)
    " Separate gerrvim_file consolidating function, called when buffer is saved
    autocmd! BufWriteCmd GerrvimCommenting
    function! s:AppendCC()
        " Collect already written comments from file if it exists
        let ccprev = []
        if filereadable(g:gerrvim_file)
            let ccprev = readfile(g:gerrvim_file)
        endif
        " Save all those consolidated data to file
        let ready = ccprev + getline(0, "$") + [""]
        call writefile(ready, g:gerrvim_file)
        setlocal nomodified
        echohl MoreMsg | echomsg "Commented:" len(ready) "lines" | echohl None
    endfunction
    autocmd BufWriteCmd GerrvimCommenting call s:AppendCC()
    " Simple syntax highlighting for that window
    syntax region CCBlock start=/^-\{5}BEGIN/ end=/^-\{5}END-\+/
    highlight link CCBlock Statement
    " Write buffer and close window after simple <CR>
    nmap <buffer> <silent> <CR> :wq<CR>
    normal zR
    startinsert
endfunction

function! s:GerrvimClear()
    call writefile([], g:gerrvim_file)
    echohl WarningMsg | echomsg "Comments are wiped" | echohl None
endfunction

command! GerrvimClear call <SID>GerrvimClear()
command! -range Gerrvim <line1>, <line2> call <SID>Gerrvim()
vnoremap <silent><Leader>cc :call <SID>Gerrvim()<CR>
