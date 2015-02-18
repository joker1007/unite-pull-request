"=============================================================================
" FILE: pull_request.vim
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

if !exists('g:github_token')
  echohl ErrorMsg | echomsg "require 'g:github_token' variables" | echohl None
  finish
endif

if !executable('curl')
  echohl ErrorMsg | echomsg "require 'curl' command" | echohl None
  finish
endif

if !exists('g:github_user')
  let g:github_user = substitute(s:system('git config --get github.user'), "\n", '', '')
  if strlen(g:github_user) == 0
    let g:github_user = $GITHUB_USER
  end
endif

if !exists('g:unite_pull_request_exclude_extensions')
  let g:unite_pull_request_exclude_extensions = [
        \ "png", "jpg", "jpeg", "gif", "pdf", "bmp",
        \ "exe", "jar", "zip", "war",
        \ "doc", "docx", "xls", "xlsx",
        \]
endif

if !exists('g:unite_pull_request_status_mark_table')
  let g:unite_pull_request_status_mark_table = {
        \ "added" : "+",
        \ "modified" : "*",
        \ "removed" : "-",
        \ }
endif

if !exists('g:unite_pull_request_endpoint_url')
  let g:unite_pull_request_endpoint_url = "https://api.github.com/"
endif

if !exists('g:unite_pull_request_fetch_per_page_size')
  let g:unite_pull_request_fetch_per_page_size = 30
endif

function! s:github_request_header()
  let auth = s:GetGitHubAuthHeader()
  return {
        \ "User-Agent" : "unite-pull-request",
        \ "Content-type" : "application/json",
        \ "Authorization" : auth,
        \ }
endfunction

function! s:github_raw_access_header()
  let auth = s:GetGitHubAuthHeader()
  return {
        \ "User-Agent" : "unite-pull-request",
        \ "Content-type" : "application/vnd.github.v3.raw",
        \ "Accept" : "application/vnd.github.v3.raw",
        \ "Authorization" : auth,
        \ }
endfunction

function! s:pull_request_list_url(path, page)
  return g:unite_pull_request_endpoint_url . "repos/" . a:path .
        \ "/pulls?page=" . a:page .
        \ "&per_page=" . g:unite_pull_request_fetch_per_page_size
endfunction

function! s:pull_request_url(path, number)
  return g:unite_pull_request_endpoint_url . "repos/" . a:path .
        \ "/pulls/" . a:number
endfunction

function! s:pull_request_files_url(path, number, page)
  return s:pull_request_url(a:path, a:number) . "/files?page=" . a:page .
        \ "&per_page=" . g:unite_pull_request_fetch_per_page_size
endfunction

function! s:pull_request_comments_url(path, number)
  return s:pull_request_url(a:path, a:number) . "/comments"
endfunction

function! s:raw_file_url(repo, sha, path)
  return "https://raw.github.com/" . a:repo . "/" . a:sha . "/" . a:path
endfunction

function! s:is_exclude_file(filename)
  let matches = matchlist(a:filename, '\.\(\w*\)$')
  if len(matches) == 0
    return 0
  endif

  let extname = matches[1]
  return index(g:unite_pull_request_exclude_extensions, extname) + 1
endfunction

function! s:has_next_page(header)
  let idx = match(a:header, '^Link:')
  if idx == -1
    return 0
  endif

  let link_header = a:header[idx]
  if match(link_header, 'res="next"')
    return 1
  endif
endfunction

function! s:build_pr_info(data)
  return {
    \ "base_sha" : a:data.base.sha,
    \ "base_ref" : a:data.base.ref,
    \ "head_sha" : a:data.head.sha,
    \ "head_ref" : a:data.head.ref,
    \ "html_url" : a:data.html_url,
    \ "state"    : a:data.state,
    \ "number"   : a:data.number
    \ }
endfunction

function! pull_request#fetch_list(repo, page)
  let res = webapi#http#get(s:pull_request_list_url(a:repo, a:page), {}, s:github_request_header())

  if res.status !~ "^2.*"
    return ['error', 'Failed to fetch pull request list']
  endif

  let content = webapi#json#decode(res.content)
  let candidates = []

  for pr in content
    let pr_info = s:build_pr_info(pr)
    let item = {
          \ "word" : "#" . pr.number . " " . pr.title,
          \ "source" : "pull_request",
          \ "action__source_name" : "pull_request_file",
          \ "action__source_args" : [a:repo, pr.number, 1, pr_info],
          \ "action__path" : "issues:repos/" . a:repo . "/issues/" . pr.number,
          \ "source__pull_request_info" : {
          \   "html_url" : pr.html_url,
          \   "state" : pr.state,
          \   "repo" : a:repo,
          \   "number" : pr.number,
          \  }
          \}
    call add(candidates, item)
  endfor

  if s:has_next_page(res.header)
    let next_page = {
      \ "word" : "=== Fetch next page ===",
      \ "source" : "pull_request",
      \ "action__source_name" : "pull_request",
      \ "action__source_args" : [a:repo, a:page + 1],
      \ }

    call add(candidates, next_page)
  endif

  return candidates
endfunction

function! pull_request#fetch_request(repo, number)
  let res = webapi#http#get(s:pull_request_url(a:repo, a:number), {}, s:github_request_header())

  if res.status !~ "^2.*"
    echo 'Failed to fetch pull request'
    return {}
  endif

  return s:build_pr_info(webapi#json#decode(res.content))
endfunction

function! pull_request#fetch_files(repo, number, page, ...)
  if a:0 > 0
    let pr_info = a:000[0]
  else
    let pr_info = pull_request#fetch_request(a:repo, a:number)
  endif

  let files_res = webapi#http#get(s:pull_request_files_url(a:repo, a:number, a:page), {}, s:github_request_header())

  if files_res.status !~ "^2.*"
    echo 'Failed to fetch pull request files'
    return []
  endif

  let files = webapi#json#decode(files_res.content)

  let candidates = []

  for f in files
    if s:is_exclude_file(f.filename)
      continue
    endif

    let item = {
          \ "word" : g:unite_pull_request_status_mark_table[f.status] . " " . f.filename,
          \ "source" : "pull_request_file",
          \ "source__file_info" : {
          \   "filename" : f.filename,
          \   "status"   : f.status,
          \   "repo"     : a:repo,
          \   "number"   : a:number,
          \   "base_sha" : pr_info.base_sha,
          \   "base_ref" : pr_info.base_ref,
          \   "head_sha" : pr_info.head_sha,
          \   "head_ref" : pr_info.head_ref,
          \   "sha" : f.sha,
          \   "blob_url" : f.blob_url,
          \   "raw_url" : f.raw_url,
          \   }
          \ }

    if has_key(f, 'patch')
      let item.source__file_info.patch = f.patch
    endif

    let item.source__file_info["fetch_base_file"] = function("s:fetch_base_file")
    let item.source__file_info["fetch_head_file"] = function("s:fetch_head_file")

    call add(candidates, item)
  endfor

  if s:has_next_page(files_res.header)
    let next_page = {
      \ "word" : "=== Fetch next page ===",
      \ "source" : "pull_request_file",
      \ "kind" : "source",
      \ "action__source_name" : "pull_request_file",
      \ "action__source_args" : [a:repo, a:number, a:page + 1, pr_info],
      \ "source__pull_request_info" : {
      \   "html_url" : pr_info.html_url,
      \   "state" : pr_info.state,
      \   "repo" : a:repo,
      \   "number" : a:number,
      \  }
      \ }

    call add(candidates, next_page)
  endif

  return candidates
endfunction

function! s:fetch_base_file() dict
  let raw_file_url = s:raw_file_url(self.repo, self.base_sha, self.filename)
  let raw_res = webapi#http#get(raw_file_url, {}, s:github_raw_access_header())
  if raw_res.status !~ "^2.*"
    echo 'Failed to fetch pull request files'
    return "error"
  endif

  return raw_res.content
endfunction

function! s:fetch_head_file() dict
  let raw_file_url = s:raw_file_url(self.repo, self.head_sha, self.filename)
  let raw_res = webapi#http#get(raw_file_url, {}, s:github_raw_access_header())
  if raw_res.status !~ "^2.*"
    echo 'Failed to fetch pull request files'
    return "error"
  endif

  return raw_res.content
endfunction

function! pull_request#post_review_comment(repo, number, comment_info)
  let json = webapi#json#encode(a:comment_info)
  let res = webapi#http#post(s:pull_request_comments_url(a:repo, a:number),
        \ json, s:github_request_header())

  if res.status =~ "^2.*"
    echo "Commented."
    return 1
  else
    echo "Failed to post comment"
    return 0
  endif
endfunction

function! pull_request#open_comment_buffer(repo, number, comment_info)
  let filename = a:comment_info.path
  let position = a:comment_info.position
  let bufname = 'pull_request_comment:' . filename . '/' . position

  let bufnr = bufwinnr(bufname)
  if bufnr > 0
    exec bufnr.'wincmd w'
  else
    exec 'botright split ' . bufname
    exec '15 wincmd _'
    call s:init_pull_request_comment_buffer()

    let b:repo = a:repo
    let b:number = a:number
    let b:comment_info = a:comment_info
  endif
endfunction

function! s:init_pull_request_comment_buffer()
  setlocal bufhidden=wipe
  setlocal buftype=acwrite
  setlocal nobuflisted
  setlocal noswapfile
  setlocal modifiable
  setlocal nomodified
  setlocal nonumber
  setlocal ft=markdown

  if !exists('b:pull_request_comment_write_cmd')
    augroup PullRequestReviewComment
      autocmd!
      autocmd BufWriteCmd <buffer> call s:post_comment()
    augroup END
    let b:pull_request_comment_write_cmd = 1
  endif

  :0
  startinsert!
endfunction

function! s:post_comment()
  let body = join(getline(1, "$"), "\n")
  let b:comment_info.body = body
  if pull_request#post_review_comment(b:repo, b:number, b:comment_info)
    setlocal nomodified
    bd!
  endif
endfunction


let s:unite_pull_request_token_file = expand(get(g:, 'unite_request_token_file', '~/.unite-pull-request'))

" from gist-vim GistGetAuthHeader (https://github.com/mattn/gist-vim) {{{
"
" License: BSD
" Copyright 2010 by Yasuhiro Matsumoto
" modification, are permitted provided that the following conditions are met:
"
" 1. Redistributions of source code must retain the above copyright notice,
"    this list of conditions and the following disclaimer.
" 2. Redistributions in binary form must reproduce the above copyright notice,
"    this list of conditions and the following disclaimer in the documentation
"    and/or other materials provided with the distribution.
"
" THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
" ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
" LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
" FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
" REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
" INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
" (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
" SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
" HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
" STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
" ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
" OF THE POSSIBILITY OF SUCH DAMAGE.
" Original Author: Yasuhiro Matsumoto
function! s:GetGitHubAuthHeader() abort
  let auth = ''
  if filereadable(s:unite_pull_request_token_file)
    let str = join(readfile(s:unite_pull_request_token_file), '')
    if type(str) == 1
      let auth = str
    endif
  endif
  if len(auth) > 0
    return auth
  endif

  redraw
  echohl WarningMsg
  echo 'unite-pull-request.vim requires authorization to use the GitHub API. These settings are stored in "~/.unite-pull-request". If you want to revoke, do "rm ~/.unite-pull-request".'
  echohl None
  let password = inputsecret('GitHub Password for '.g:github_user.':')
  if len(password) == 0
    let v:errmsg = 'Canceled'
    return ''
  endif
  let note = 'unite-pull-request.vim on '.hostname().' '.strftime('%Y/%m/%d-%H:%M:%S')
  let note_url = 'https://github.com/joker1007/unite-pull-request'
  let insecureSecret = printf('basic %s', webapi#base64#b64encode(g:github_user.':'.password))
  let res = webapi#http#post(g:unite_pull_request_endpoint_url.'authorizations', webapi#json#encode({
              \  "scopes"   : ["repo"],
              \  "note"     : note,
              \  "note_url" : note_url,
              \}), {
              \  "Content-Type"  : "application/json",
              \  "Authorization" : insecureSecret,
              \})
  let h = filter(res.header, 'stridx(v:val, "X-GitHub-OTP:") == 0')
  if len(h)
    let otp = inputsecret('OTP:')
    if len(otp) == 0
      let v:errmsg = 'Canceled'
      return ''
    endif
    let res = webapi#http#post(g:unite_pull_request_endpoint_url.'authorizations', webapi#json#encode({
                \  "scopes"   : ["repo"],
                \  "note"     : note,
                \  "note_url" : note_url,
                \}), {
                \  "Content-Type"  : "application/json",
                \  "Authorization" : insecureSecret,
                \  "X-GitHub-OTP"  : otp,
                \})
  endif
  let authorization = webapi#json#decode(res.content)
  if has_key(authorization, 'token')
    let secret = printf('token %s', authorization.token)
    call writefile([secret], s:unite_pull_request_token_file)
    if !(has('win32') || has('win64'))
      call system('chmod go= '.s:unite_pull_request_token_file)
    endif
  elseif has_key(authorization, 'message')
    let secret = ''
    let v:errmsg = authorization.message
  endif
  return secret
endfunction
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
