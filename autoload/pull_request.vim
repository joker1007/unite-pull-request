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

let s:endpoint_url = "https://api.github.com/"

let s:github_request_header = {
        \ "User-Agent" : "unite-pull-request",
        \ "Content-type" : "application/json",
        \ "Authorization" : "Basic " .
        \   webapi#base64#b64encode(g:github_token . ":x-oauth-basic")
        \ }

function! s:pull_request_list_url(path)
  return s:endpoint_url . "repos/" . a:path . "/pulls"
endfunction

function! s:pull_request_url(path, number)
  return s:endpoint_url . "repos/" . a:path . "/pulls/" . a:number
endfunction

function! s:pull_request_files_url(path, number)
  return s:endpoint_url . "repos/" . a:path . "/pulls/" . a:number . "/files"
endfunction

function! s:raw_file_url(repo, sha, path)
  return "https://raw.github.com/" . a:repo . "/" . a:sha . "/" . a:path
endfunction

function! pull_request#fetch_list(repo)
  let res = webapi#http#get(s:pull_request_list_url(a:repo), {}, s:github_request_header)

  if res.status !~ "^2.*"
    return ['error', 'Failed to fetch pull request list']
  endif

  let content = webapi#json#decode(res.content)
  let candidates = []

  for pr in content
    let item = {
          \ "word" : "#" . pr.number . " " . pr.title,
          \ "source" : "pull_request",
          \ "action__source_name" : "pull_request_file",
          \ "action__source_args" : [a:repo, pr.number],
          \ "source__pull_request_info" : {
          \   "html_url" : pr.html_url,
          \   "state" : pr.state,
          \   "repo" : a:repo,
          \   "number" : pr.number,
          \  }
          \}
    call add(candidates, item)
  endfor

  return candidates
endfunction

function! pull_request#fetch_request(repo, number)
  let res = webapi#http#get(s:pull_request_url(a:repo, a:number), {}, s:github_request_header)

  if res.status !~ "^2.*"
    echo 'Failed to fetch pull request'
    return {}
  endif

  let content = webapi#json#decode(res.content)
  return {
        \ "base_sha" : content.base.sha,
        \ "base_ref" : content.base.ref,
        \ "head_sha" : content.head.sha,
        \ "head_ref" : content.head.ref,
        \}
endfunction

function! pull_request#fetch_files(repo, number)
  let pr_info = pull_request#fetch_request(a:repo, a:number)

  let files_res = webapi#http#get(s:pull_request_files_url(a:repo, a:number), {}, s:github_request_header)

  if files_res.status !~ "^2.*"
    echo 'Failed to fetch pull request files'
    return []
  endif

  let files = webapi#json#decode(files_res.content)

  let candidates = []

  for f in files
    let matches = matchlist(f.filename, '\.\(\w*\)$')
    if len(matches) > 1
      let extname = matches[1]
      if index(g:unite_pull_request_exclude_extensions, extname) != -1
        continue
      endif
    endif

    let item = {
          \ "word" : g:unite_pull_request_status_mark_table[f.status] . " " . f.filename,
          \ "source" : "pull_request_file",
          \ "source__file_info" : {
          \   "filename" : f.filename,
          \   "status" : f.status,
          \   "repo"   : a:repo,
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

    function! item.source__file_info.fetch_base_file()
      let raw_file_url = s:raw_file_url(self.repo, self.base_sha, self.filename)
      let header = deepcopy(s:github_request_header)
      let header["Content-type"] = "application/vnd.github.v3.raw"
      let header["Accept"] = "application/vnd.github.v3.raw"
      let raw_res = webapi#http#get(raw_file_url, {}, header)
      if raw_res.status !~ "^2.*"
        echo 'Failed to fetch pull request files'
        return "error"
      endif

      return raw_res.content
    endfunction

    function! item.source__file_info.fetch_head_file()
      let raw_file_url = s:raw_file_url(self.repo, self.head_sha, self.filename)
      let header = deepcopy(s:github_request_header)
      let header["Content-type"] = "application/vnd.github.v3.raw"
      let header["Accept"] = "application/vnd.github.v3.raw"
      let raw_res = webapi#http#get(raw_file_url, {}, header)
      if raw_res.status !~ "^2.*"
        echo 'Failed to fetch pull request files'
        return "error"
      endif

      return raw_res.content
    endfunction

    call add(candidates, item)
  endfor

  return candidates
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
