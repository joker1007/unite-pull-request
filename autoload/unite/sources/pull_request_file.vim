"=============================================================================
" FILE: unite/sources/pull_request_file.vim
" AUTHOR:  Tomohiro Hashidate (joker1007) <kakyoin.hierophant@gmail.com>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

let s:unite_source = {}
let s:unite_source.name = 'pull_request_file'
let s:unite_source.description = 'candidates from changed files of a pull request'
let s:unite_source.default_action = { 'common' : 'diffopen' }
let s:unite_source.action_table = {}

function! s:unite_source.gather_candidates(args, context)
  if len(a:args) != 2
    echoerr "this source requires two args (repository name, pull request number)"
    return []
  endif

  let repo = a:args[0]
  let number = a:args[1]
  return pull_request#fetch_files(repo, number)
endfunction

function! unite#sources#pull_request_file#define()
  return s:unite_source
endfunction

let s:action_table = {}
let s:unite_source.action_table.common = s:action_table

let s:action_table.diffopen = {
      \ 'description' : 'diff open base file and head file',
      \ 'is_quit' : 0,
      \ }
function! s:action_table.diffopen.func(candidate)
  let status = a:candidate.source__file_info.status

  if status == "added"
    tabnew [nofile]
    let t:title = 'vimdiff'
    if &modifiable
      call setline(1, "[no file]")
    endif
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal nobuflisted
    setlocal noswapfile
    setlocal nomodified
    setlocal nomodifiable
    setlocal readonly
    setlocal splitright

    execute "vsplit " . a:candidate.source__file_info.head_file
  elseif status == "removed"
    execute "tabnew " . a:candidate.source__file_info.base_file
    let t:title = 'vimdiff'
    setlocal splitright

    vsplit [deleted]
    if &modifiable
      call setline(1, "[deleted]")
    endif
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal nobuflisted
    setlocal noswapfile
    setlocal nomodified
    setlocal nomodifiable
    setlocal readonly
  else
    execute "tabnew " . a:candidate.source__file_info.base_file
    let t:title = 'vimdiff'
    setlocal splitright
    execute "vertical diffsplit " . a:candidate.source__file_info.head_file
  endif

endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
