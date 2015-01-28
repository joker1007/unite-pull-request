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

let g:unite_pull_request_endpoint_url = "https://api.github.com/"

lua << LUA
local ltn12 = require("ltn12")
local mime = require("mime")
local base64 = ltn12.filter.chain(
  mime.encode("base64"),
  mime.wrap("base64")
)

upr_github = {}
upr_github.token = vim.eval('g:github_token')
upr_github.exclude_extensions = vim.eval('g:unite_pull_request_exclude_extensions')
upr_github.encoded_token = base64(upr_github.token .. ":x-oauth-basic")

upr_github.unite_pull_request_status_mark_table = vim.eval('g:unite_pull_request_status_mark_table')

upr_github.github_request_header = {}
upr_github.github_request_header["User-Agent"] = "unite-pull-request"
upr_github.github_request_header["Content-type"] = "application/json"
upr_github.github_request_header["Authorization"] = "Basic " .. upr_github.encoded_token

upr_github.github_raw_request_header = {}
upr_github.github_raw_request_header["User-Agent"] = "unite-pull-request"
upr_github.github_raw_request_header["Content-type"] = "application/vnd.github.v3.raw"
upr_github.github_raw_request_header["Accept"] = "application/vnd.github.v3.raw"
upr_github.github_raw_request_header["Authorization"] = "Basic " .. upr_github.encoded_token

upr_github.pull_request_list_url = function(path)
  return vim.eval("g:unite_pull_request_endpoint_url") .. "repos/" .. path .. "/pulls"
end

upr_github.pull_request_url = function(path, number)
  return upr_github.pull_request_list_url(path) .. "/" .. tostring(number)
end

upr_github.pull_request_files_url = function(path, number)
  return upr_github.pull_request_url(path, number) .. "/files"
end

upr_github.raw_file_url = function(repo, sha, path)
  return "https://raw.github.com/" .. repo .. "/" .. sha .. "/" .. path
end
LUA

let s:github_request_header = {
        \ "User-Agent" : "unite-pull-request",
        \ "Content-type" : "application/json",
        \ "Accept" : "application/json",
        \ "Authorization" : "Basic " .
        \   webapi#base64#b64encode(g:github_token . ":x-oauth-basic")
        \ }

let s:github_raw_access_header = {
        \ "User-Agent" : "unite-pull-request",
        \ "Content-type" : "application/vnd.github.v3.raw",
        \ "Accept" : "application/vnd.github.v3.raw",
        \ "Authorization" : "Basic " .
        \   webapi#base64#b64encode(g:github_token . ":x-oauth-basic")
        \ }

function! s:pull_request_list_url(path)
  return g:unite_pull_request_endpoint_url . "repos/" . a:path . "/pulls"
endfunction

function! s:pull_request_url(path, number)
  return s:pull_request_list_url(a:path) . "/" . a:number
endfunction

function! s:pull_request_files_url(path, number)
  return s:pull_request_url(a:path, a:number) . "/files"
endfunction

function! s:pull_request_comments_url(path, number)
  return s:pull_request_url(a:path, a:number) . "/comments"
endfunction

function! s:raw_file_url(repo, sha, path)
  return "https://raw.github.com/" . a:repo . "/" . a:sha . "/" . a:path
endfunction

function! s:is_exclude_file(filename) abort
  let matches = matchlist(a:filename, '\.\(\w*\)$')
  if len(matches) > 1
    let extname = matches[1]
    return index(g:unite_pull_request_exclude_extensions, extname)
  endif
endfunction

function! pull_request#fetch_list(repo)
  let results = []
  lua <<LUA
    local ltn12 = require("ltn12")
    local http = require("ssl.https")
    local cjson = require("cjson")

    local repo = vim.eval("a:repo")
    local results = vim.eval('results')
    local resp = {}

    local r, c, h = http.request{
      url = upr_github.pull_request_list_url(repo),
      method = "GET",
      protocol = "tlsv1",
      headers = upr_github.github_request_header,
      sink = ltn12.sink.table(resp),
      options = "all",
      verify = "none"
    }

    if string.find(c, "^2.*") then
      local data = cjson.decode(table.concat(resp))

      for i, pr in ipairs(data) do
        local pr_info = vim.dict()
        pr_info.base_sha = pr.base.sha
        pr_info.base_ref = pr.base.ref
        pr_info.head_sha = pr.head.sha
        pr_info.head_ref = pr.head.ref

        local item = vim.dict()
        action__source_args = vim.list()
        action__source_args:add(repo)
        action__source_args:add(tostring(pr.number))
        action__source_args:add(pr_info)

        item.word = "#" .. tostring(pr.number) .. " " .. pr.title
        item.source = "pull_request"
        item.action__source_name = "pull_request_file"
        item.action__source_args = action__source_args

        local source__pull_request_info = vim.dict()
        source__pull_request_info.html_url = pr.html_url
        source__pull_request_info.state = pr.state
        source__pull_request_info.repo = repo
        source__pull_request_info.number = tostring(pr.number)

        item.source__pull_request_info = source__pull_request_info

        results:add(item)
      end
    end
LUA

  if empty(results)
    return ["error", "Failed to fetch pull request list"]
  endif

  return results
endfunction

function! pull_request#fetch_request(repo, number)
  let content = {}

  lua <<LUA
    local ltn12 = require("ltn12")
    local http = require("ssl.https")
    local cjson = require("cjson")

    local repo = vim.eval("a:repo")
    local number = vim.eval("a:number")
    local resp = {}

    local r, c, h = http.request{
      url = upr_github.pull_request_url(repo, number),
      method = "GET",
      protocol = "tlsv1",
      headers = upr_github.github_request_header,
      sink = ltn12.sink.table(resp),
      options = "all",
      verify = "none"
    }
    if string.find(c, "^2.*") then
      local data = cjson.decode(table.concat(resp))

      local content = vim.eval('content')
      content.base_sha = data.base.sha
      content.base_ref = data.base.ref
      content.head_sha = data.head.sha
      content.head_ref = data.head.ref
    else
      print('Failed to fetch pull request')
    end
LUA

  return content
endfunction

function! pull_request#fetch_files(repo, number, ...)
  if a:0 > 0
    let pr_info = a:000[0]
  else
    let pr_info = pull_request#fetch_request(a:repo, a:number)
  endif

  let results = []

  lua <<LUA
    local ltn12 = require("ltn12")
    local http = require("ssl.https")
    local cjson = require("cjson")

    local repo = vim.eval("a:repo")
    local number = vim.eval("a:number")
    local results = vim.eval("results")
    local pr_info = vim.eval("pr_info")
    local resp = {}

    local r, c, h = http.request{
      url = upr_github.pull_request_files_url(repo, number),
      method = "GET",
      protocol = "tlsv1",
      headers = upr_github.github_request_header,
      sink = ltn12.sink.table(resp),
      options = "all",
      verify = "none"
    }

    if string.find(c, "^2.*") then
      local data = cjson.decode(table.concat(resp))

      for i, f in ipairs(data) do
        if vim.eval('s:is_exclude_file("' .. f.filename .. '")') == -1 then
          local source__file_info = vim.dict()
          source__file_info.filename = f.filename
          source__file_info.status = f.status
          source__file_info.repo = repo
          source__file_info.number = number
          source__file_info.base_sha = pr_info.base_sha
          source__file_info.base_ref = pr_info.base_ref
          source__file_info.head_sha = pr_info.head_sha
          source__file_info.head_ref = pr_info.head_ref
          source__file_info.sha = f.sha
          source__file_info.blob_url = f.blob_url
          source__file_info.raw_url = f.raw_url
          if f.patch then
            source__file_info.patch = f.patch
          end

          local item = vim.dict()
          item.word = upr_github.unite_pull_request_status_mark_table[f.status] .. " " .. f.filename
          item.source = "pull_request_file"
          item.source__file_info = source__file_info

          results:add(item)
        end
      end
    end
LUA

  if empty(results)
    echo 'Failed to fetch pull request files'
    return results
  endif

  for item in results
    let item.source__file_info["fetch_base_file"] = function("s:fetch_base_file")
    let item.source__file_info["fetch_head_file"] = function("s:fetch_head_file")
  endfor

  return results
endfunction

function! s:fetch_base_file() dict
  let raw_file_url = s:raw_file_url(self.repo, self.base_sha, self.filename)
  let raw_res = webapi#http#get(raw_file_url, {}, s:github_raw_access_header)
  if raw_res.status !~ "^2.*"
    echo 'Failed to fetch pull request files'
    return "error"
  endif

  return raw_res.content
endfunction

function! s:fetch_head_file() dict
  let raw_file_url = s:raw_file_url(self.repo, self.head_sha, self.filename)
  let raw_res = webapi#http#get(raw_file_url, {}, s:github_raw_access_header)
  if raw_res.status !~ "^2.*"
    echo 'Failed to fetch pull request files'
    return "error"
  endif

  return raw_res.content
endfunction

function! pull_request#post_review_comment(repo, number, comment_info)
  let json = webapi#json#encode(a:comment_info)
  let res = webapi#http#post(s:pull_request_comments_url(a:repo, a:number),
        \ json, s:github_request_header)

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

let &cpo = s:save_cpo
unlet s:save_cpo
