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
  if len(a:args) < 2
    echoerr "this source requires two args (repository name, pull request number)"
    return []
  endif

  let repo = a:args[0]
  let number = a:args[1]
  let page = 1

  if len(a:args) > 2
    let page = a:args[2]
  endif

  if len(a:args) > 3
    let pr_info = a:args[3]
    return pull_request#fetch_files(repo, number, page, pr_info)
  else
    return pull_request#fetch_files(repo, number, page)
  endif
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
      \ 'is_selectable' : 1,
      \ 'is_quit' : 0,
      \ }
function! s:action_table.diffopen.func(candidate)
  for item in a:candidate
    let status = item.source__file_info.status
    if status == "added"
      tabnew [nofile]
      if &modifiable
        call setline(1, "[no file]")
      endif
      call s:init_file_setting()
      setlocal splitright

      execute "vsplit " .
            \ item.source__file_info.head_ref . "/" .
            \ item.source__file_info.filename
      if &modifiable
        let head_file = item.source__file_info.fetch_head_file()
        silent put =head_file
        execute "1delete"
        call s:init_file_setting()
        call s:define_buffer_cmd(item.source__file_info)
      endif
    elseif status == "removed"
      silent execute "tabnew " .
            \ item.source__file_info.base_ref . "/" .
            \ item.source__file_info.filename
      if &modifiable
        let base_file = item.source__file_info.fetch_base_file()
        silent put =base_file
        execute "1delete"
        call s:init_file_setting()
        call s:define_buffer_cmd(item.source__file_info)
      endif
      setlocal splitright

      vsplit [deleted]
      if &modifiable
        call setline(1, "[deleted]")
      endif
      call s:init_file_setting()
    else
      silent execute "tabnew " .
            \ item.source__file_info.base_ref . "/" .
            \ item.source__file_info.filename
      if &modifiable
        let base_file = item.source__file_info.fetch_base_file()
        silent put =base_file
        execute "1delete"
        call s:init_file_setting()
      endif
      setlocal splitright
      diffthis

      silent execute "vsplit " .
            \ item.source__file_info.head_ref . "/" .
            \ item.source__file_info.filename
      if &modifiable
        let head_file = item.source__file_info.fetch_head_file()
        silent put =head_file
        execute "1delete"
        call s:init_file_setting()
      endif
      diffthis

      silent execute "botright split " .
            \ item.source__file_info.head_ref . "/" .
            \ item.source__file_info.filename . ".patch"
      if &modifiable
        let patch = item.source__file_info.patch
        silent put =patch
        execute "1delete"
        call s:init_file_setting()
        call s:define_buffer_cmd(item.source__file_info)
      endif
    endif
  endfor
endfunction

function! s:define_buffer_cmd(source__file_info)
  let b:source__file_info = a:source__file_info
  command! -buffer PrCommentPost
        \ call s:open_comment_buffer()
  nnoremap <silent><buffer> <Enter> :<C-U>PrCommentPost<CR>
endfunction

function! s:open_comment_buffer()
  let repo = b:source__file_info.repo
  let number = b:source__file_info.number

  let position = line(".")
  if b:source__file_info.status == "modified"
    let position = position - 1
  endif

  let comment_info = {
        \ "commit_id" : b:source__file_info.head_sha,
        \ "path"      : b:source__file_info.filename,
        \ "position"  : position,
        \ }

  call pull_request#open_comment_buffer(repo, number, comment_info)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
