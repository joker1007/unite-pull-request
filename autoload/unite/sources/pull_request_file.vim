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
let s:unite_source.syntax = 'uniteSource__PullRequest'
let s:unite_source.hooks = {}

function! s:init_file_setting()
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal nobuflisted
  setlocal noswapfile
  setlocal nomodified
  setlocal nomodifiable
  setlocal readonly
endfunction

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

function! s:unite_source.hooks.on_syntax(args, context)
  execute "syntax match uniteSource_PullRequest_Added /".g:unite_pull_request_status_mark_table.added." .*/ contained containedin=uniteSource__PullRequest"
  execute "syntax match uniteSource_PullRequest_Removed /".g:unite_pull_request_status_mark_table.removed." .*/ contained containedin=uniteSource__PullRequest"
  execute "syntax match uniteSource_PullRequest_Modified /".g:unite_pull_request_status_mark_table.modified." .*/ contained containedin=uniteSource__PullRequest"

  highlight link uniteSource_PullRequest_Added DiffAdd
  highlight link uniteSource_PullRequest_Removed DiffDelete
  highlight link uniteSource_PullRequest_Modified DiffChange
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
    if &modifiable
      call setline(1, "[no file]")
    endif
    call s:init_file_setting()
    setlocal splitright

    execute "vsplit " .
          \ a:candidate.source__file_info.head_ref . "/" .
          \ a:candidate.source__file_info.filename
    if &modifiable
      let head_file = a:candidate.source__file_info.fetch_head_file()
      silent put =head_file
      execute "1delete"
      call s:init_file_setting()
    endif
  elseif status == "removed"
    silent execute "tabnew " .
          \ a:candidate.source__file_info.base_ref . "/" .
          \ a:candidate.source__file_info.filename
    if &modifiable
      let base_file = a:candidate.source__file_info.fetch_base_file()
      silent put =base_file
      execute "1delete"
      call s:init_file_setting()
    endif
    setlocal splitright

    vsplit [deleted]
    if &modifiable
      call setline(1, "[deleted]")
    endif
    call s:init_file_setting()
  else
    silent execute "tabnew " .
          \ a:candidate.source__file_info.base_ref . "/" .
          \ a:candidate.source__file_info.filename
    if &modifiable
      let base_file = a:candidate.source__file_info.fetch_base_file()
      silent put =base_file
      execute "1delete"
      call s:init_file_setting()
    endif
    setlocal splitright
    diffthis

    silent execute "vsplit " .
          \ a:candidate.source__file_info.head_ref . "/" .
          \ a:candidate.source__file_info.filename
    if &modifiable
      let head_file = a:candidate.source__file_info.fetch_head_file()
      silent put =head_file
      execute "1delete"
      call s:init_file_setting()
    endif
    diffthis
  endif

endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
