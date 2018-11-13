local BasePlugin = require "kong.plugins.base_plugin"
local body_transformer = require "kong.plugins.response-transformer.body_transformer"
local header_transformer = require "kong.plugins.response-transformer.header_transformer"


local is_body_transform_set = header_transformer.is_body_transform_set
local is_json_body = header_transformer.is_json_body
local concat = table.concat
local kong = kong
local ngx = ngx


local ResponseTransformerHandler = BasePlugin:extend()


function ResponseTransformerHandler:new()
  ResponseTransformerHandler.super.new(self, "response-transformer")
end


function ResponseTransformerHandler:header_filter(conf)
  ResponseTransformerHandler.super.header_filter(self)

  if kong.response.get_source() ~= "service" then
    return
  end

  header_transformer.transform_headers(conf)
end


function ResponseTransformerHandler:body_filter(conf)
  ResponseTransformerHandler.super.body_filter(self)

  if kong.response.get_source() ~= "service" or
     not (is_body_transform_set(conf) and
          is_json_body(kong.request.get_header("Content-Type"))) then
    return
  end

  local ctx = ngx.ctx
  local chunk, eof = ngx.arg[1], ngx.arg[2]

  ctx.rt_body_chunks = ctx.rt_body_chunks or {}
  ctx.rt_body_chunk_number = ctx.rt_body_chunk_number or 1

  if eof then
    local body = body_transformer.transform_json_body(conf, concat(ctx.rt_body_chunks))
    ngx.arg[1] = body
  else
    ctx.rt_body_chunks[ctx.rt_body_chunk_number] = chunk
    ctx.rt_body_chunk_number = ctx.rt_body_chunk_number + 1
    ngx.arg[1] = nil
  end
end


ResponseTransformerHandler.PRIORITY = 800
ResponseTransformerHandler.VERSION = "1.0.0"


return ResponseTransformerHandler
