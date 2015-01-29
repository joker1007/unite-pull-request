"=============================================================================
" FILE: unite/sources/pull_request.vim
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
let s:unite_source.name = 'pull_request'
let s:unite_source.description = "candidates from GitHub pull requests"
let s:unite_source.default_kind = 'source'
let s:unite_source.default_action = 'start'
let s:unite_source.action_table = {}

function! s:unite_source.gather_candidates(args, context)
  if len(a:args) < 1
    echoerr "this source requires at least one arg (repository name)"
    return []
  endif

  let repo = a:args[0]

  let page = 1
  if len(a:args) == 2
    let page = a:args[1]
  endif

  return pull_request#fetch_list(repo, page)
endfunction

function! unite#sources#pull_request#define()
  return s:unite_source
endfunction

let s:action_table = {}
let s:unite_source.action_table.source = s:action_table

let s:action_table.browse = {
      \ 'description' : 'browser open pull request page',
      \ 'is_quit' : 0,
      \ }
function! s:action_table.browse.func(candidate)
  let url = a:candidate.source__pull_request_info.html_url

  call openbrowser#open(url)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
