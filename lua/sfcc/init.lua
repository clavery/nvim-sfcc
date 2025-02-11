---@mod sfcc extend dap to support SFCC debugging, etc

local PROPHET_VSIX =
  "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/SqrTT/vsextensions/prophet/1.4.40/vspackage"
local PROPHET_VSIX_FILENAME = "SqrTT.prophet-1.4.40.vsix"
local PROPHET_VSIX_DEBUG_ADAPTER = "extension/dist/mockDebug.js"

-- download PROPHET_VSIX and extract it (it's a gzipped tarbal) to a neovim runtime share directory

local M = {}

local function ensure_prophet_debug_adapter()
  local share_dir = vim.fn.stdpath("data") .. "/debug-adapters/prophet"
  local vsix_path = share_dir .. "/" .. PROPHET_VSIX_FILENAME
  local debug_adapter_path = share_dir .. "/" .. PROPHET_VSIX_DEBUG_ADAPTER

  -- Check if debug adapter already exists
  if vim.fn.filereadable(debug_adapter_path) == 1 then
    return debug_adapter_path
  end

  -- Create directory if it doesn't exist
  if vim.fn.isdirectory(share_dir) == 0 then
    vim.fn.mkdir(share_dir, "p")
  end

  -- Download VSIX if it doesn't exist
  if vim.fn.filereadable(vsix_path) == 0 then
    vim.notify("[nvim-sfcc] Downloading Prophet Debug Adapter...")
    local curl_cmd = string.format("curl -L -o %s %s", vim.fn.shellescape(vsix_path), vim.fn.shellescape(PROPHET_VSIX))

    local output = vim.fn.system(curl_cmd)
    if vim.v.shell_error ~= 0 then
      vim.notify("[nvim-sfcc] Failed to download VSIX: " .. output, vim.log.levels.ERROR)
      return
    end
  end

  -- Extract VSIX (it's a tarball)
  vim.notify("[nvim-sfcc] Extracting Prophet Debug Adapter...")
  local tar_cmd = string.format("tar xzf %s -C %s", vim.fn.shellescape(vsix_path), vim.fn.shellescape(share_dir))

  local output = vim.fn.system(tar_cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("[nvim-sfcc] Failed to extract VSIX: " .. output, vim.log.levels.ERROR)
    return
  end

  -- Verify extraction
  if vim.fn.filereadable(debug_adapter_path) == 0 then
    vim.notify("[nvim-sfcc] Debug adapter not found after extraction", vim.log.levels.ERROR)
    return
  end

  -- Optionally, remove the downloaded VSIX file
  vim.fn.delete(vsix_path)

  return debug_adapter_path
end

-- ensure we can actually install this ourselves
local function check_requirements_for_download()
  if vim.fn.executable("curl") == 0 then
    error("curl is not installed")
  end
  if vim.fn.executable("tar") == 0 then
    error("tar is not installed")
  end
end

-- Where to find node
M.node_path = "node"

local default_opts = {
  node_path = M.node_path,
  setup_lsp_config = true,
  include_configs = false,
}

local function load_dap()
  local ok, dap = pcall(require, "dap")
  assert(ok, "nvim-dap is required to use nvim-sfcc")
  return dap
end

local function load_config(instance)
  local dwjson = vim.fn.getcwd() .. "/dw.json"
  local dwjs = vim.fn.getcwd() .. "/dw.js"

  local jsstat = vim.loop.fs_stat(dwjs)
  local stat = vim.loop.fs_stat(dwjson)
  local content
  if jsstat and jsstat.type == "file" then
    local cmd = string.format("%s -e 'console.log(JSON.stringify(require(\"./dw.js\")))'", M.node_path)
    local handle = io.popen(cmd)
    if handle then
      content = handle:read("*a")
      handle:close()
    end
  elseif stat and stat.type == "file" then
    local f = io.open(dwjson, "r")
    if not f then
      return {}
    end
    content = f:read("*a")
    f:close()
  else
    return {}
  end

  local json = vim.fn.json_decode(content) or {}

  if instance and json.name == instance then
    return json
  elseif instance and json.configs then
    for _, config in ipairs(json.configs) do
      if config.name == instance then
        return config
      end
    end

    -- no instance found
    error(string.format("No instance found in dwjson config for %s", instance))
  elseif not json.active and json.configs then
    for _, config in ipairs(json.configs) do
      if config.active then
        return config
      end
    end
  end
  -- no other active found
  return json
end

local function find_cartridges()
  local project_dirs = {}
  local uv = vim.loop

  local function scan_dir(path)
    local handle = uv.fs_scandir(path)
    if not handle then
      return
    end

    while true do
      local name, type = uv.fs_scandir_next(handle)
      if not name then
        break
      end

      local full_path = path .. "/" .. name

      if type == "directory" then
        scan_dir(full_path)
      elseif name == ".project" then
        table.insert(project_dirs, path)
        break -- No need to continue scanning this directory
      end
    end
  end

  scan_dir(vim.fn.getcwd())
  return project_dirs
end

local function get_script_path()
  local source = debug.getinfo(2, "S").source
  if source:sub(1, 1) == "@" then
    local file = source:sub(2)
    return vim.fn.fnamemodify(file, ":p:h") .. "/"
  end
  error("Could not determine plugin root")
end

---@param opts? sfcc.setup.opts
function M.setup(opts)
  local dap = load_dap()
  opts = vim.tbl_extend("keep", opts or {}, default_opts)
  M.node_path = opts.node_path or M.node_path

  local prophet_path = opts.prophet_debug_adapter
  if opts.prophet_auto_download then
    check_requirements_for_download()
    prophet_path = ensure_prophet_debug_adapter()
  end

  assert(prophet_path, "[nvim-sfcc] prophet_debug_adapater or prophet_auto_download option is required")

  -- check if prophet_path is a file
  local stat = vim.loop.fs_stat(prophet_path)
  if not stat or stat.type ~= "file" then
    error("[nvim-sfcc] prophetDebugAdapter must be a valid file path")
  end

  dap.adapters.prophet = function(cb, config)
    local adapter = {
      type = "server",
      host = "localhost",
      port = "${port}",
      executable = {
        command = M.node_path,
        args = { prophet_path, "--server=${port}" },
      },
      options = {
        source_filetype = "javascript",
      },
    }
    cb(adapter)
  end
  dap.adapters.sfcc = dap.adapters.prophet

  dap.listeners.before["event_initialized"]["sfcc-nvim"] = function(session, body)
    --print("Session initialized", vim.inspect(session), vim.inspect(body))
  end
  dap.listeners.before["event_prophet.getdebugger.config"]["sfcc-nvim"] = function(session)
    -- prophet debug adapter uses a custom event to request SFCC specific config
    -- it expects a DebuggerConfig DAP request in response before it will
    -- initialize the session

    ---@class ProphetConnectionConfig
    ---@field version string code version
    ---@field hostname string sfcc instance hostname
    ---@field password string sfcc password
    ---@field username string sfcc username
    ---@field verbose boolean verbose logging from DA

    ---@class ProphetDebuggerConfig
    ---@field config ProphetConnectionConfig
    ---@field cartridges string[]

    -- print(vim.inspect(session))

    local instance = nil
    if session.config and session.config.sfcc then
      instance = session.config.sfcc.instance
    end

    local dwjson = load_config(instance)
    local cartridges = find_cartridges()

    if session.config and session.config.sfcc then
      dwjson = vim.tbl_extend("force", dwjson, session.config.sfcc)
    end

    local config = {
      version = dwjson["code-version"],
      hostname = dwjson.hostname,
      password = dwjson.password,
      username = dwjson.username,
    }

    -- print(vim.inspect(config))

    -- send DebuggerConfig request
    local err, result = session:request("DebuggerConfig", {
      config = vim.tbl_extend("keep", config, {
        verbose = true,
      }),
      cartridges = cartridges,
    })
    if err then
      vim.notify("SFCC Debug Error", err)
    end
  end
  dap.listeners.on_config["sfcc-nvim"] = function(config)
    --print("Session config", vim.inspect(config))
    return vim.deepcopy(config)
  end

  if opts.include_configs then
    local configs = dap.configurations.prophet or {}
    dap.configurations.sfcc = configs
    table.insert(configs, {
      type = "prophet",
      request = "launch",
      name = "Attach to Sandbox",
    })
  end

  if opts.setup_lsp_config then
    -- pcall require lspconfig and notify error if not available
    local ok, lspconfig = pcall(require, "lspconfig")
    if not ok then
      vim.notify("[nvim-sfcc] lspconfig is required to setup LSP configurations", vim.log.levels.ERROR)
      return
    end

    local resolver_path = vim.fn.fnamemodify(get_script_path() .. "../js", ":p")

    lspconfig.ts_ls.setup({
      init_options = {
        plugins = {
          {
            name = "sfcc-resolver",
            location = resolver_path,
          },
        },
        -- tsserver = {
        --   logVerbosity = "verbose",
        -- },
      },
    })
  end
end

---@class sfcc.setup.opts
---@field prophet_auto_download? boolean Automatically download Prophet Debug Adapter
---@field prophet_debug_adapter? string Path to prophet debug adapter mockDebug.js
---@field node_path? string Path to node executable (default node)
---@field include_configs? boolean Add default configurations
---@field setup_lsp_config? boolean Setup LSPconfig configurations for ts_ls
return M
