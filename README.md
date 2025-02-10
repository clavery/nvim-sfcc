# nvim-sfcc

A Neovim plugin for Salesforce Commerce Cloud (SFCC) development.

![screenshot](./docs/screenshot.png)

## Features

- [x] DEBUGGER: [nvim-dap][1] extension that integrates the [Prophet][2] VSCode debug adapter into Neovim

## TODO

- [ ] better error handling!
- [ ] better syntax support
- [ ] language server auto config

### Out of Scope

- code/cartridge upload/watching
  - this is better handled by separate tools (see [sfcc-ci][3] or [b2c-tools][4]; b2c-tools has `code watch`, `code upload`, and `code download` commands)
- log viewing/tailing
  - see [b2c-tools][4] for a `tail` command
- SFCC types
  - use nvim's LSP plugins and your `tsconfig.json` or `jsconfig.json` and add types from [https://github.com/SalesforceCommerceCloud/dw-api-types](https://github.com/SalesforceCommerceCloud/dw-api-types) or [https://github.com/openmindlab/sfcc-dts/](https://github.com/openmindlab/sfcc-dts/)

## Installation

### Dependencies

- [Neovim](https://neovim.io/)
- [Node.js](https://nodejs.org/en/) (recommend v16)
- [nvim-dap][1]

Optional:

- [nvim-dap-ui][5] - this is the UI seen in the screenshot above
- [Prophet][2] - this provides the debugger for SFCC. If requested this will be downloaded automatically.

### Plugin

Use your favorite plugin manager to install an configure plugin. You must specify one of `prophet_auto_download` or `prophet_debug_adapter`. For example, with lazy.nvim:

```lua
{ 
  "clavery/nvim-sfcc", 
  dependencies = {"mfussenegger/nvim-dap"},
  opts = { 
    -- auto download the latest version of Prophet
    prophet_auto_download = true
    -- OR configure the path to the Prophet debug adapter you built yourself from source
    -- prophet_debug_adapter = "/path/to/prophet/dist/mockDebug.js",

    -- (optional) configure to location to nodejs; default to `node` on your path
    node_path = "/path/to/node",

    -- (optional) include default Sandbox Attach configuration (in lieu of a .vscode/launch.json)
    include_configs = false
  }
}
```

## Usage

Make sure you have a `dw.json` or `dw.js` file in your working directory. If `dw.js` is found it will be excuted using nodejs (via `node_path` configuration option) and the module exports will be parsed as JSON as if it was a `dw.json` file (this is the same behavior as Prophet). Note you can use the multiple instances convention in the style of [b2c-tools][4].

```json
{
  "name": "default",
  "active": true,
  "hostname": "abcd-001.dx.commercecloud.salesforce.com",
  "username": "...",
  "password": "...",
  "code-version": "version1",
  "configs": [{
    "name": "sandbox002",
    "active": false,
    "hostname": "abcd-002.dx.commercecloud.salesforce.com",
    "username": "...",
    "password": "...",
    "code-version": "version1",
  }]
}
```

Add at least 1 `.vscode/launch.json` configuration to your project (see that you can override `dw.json` keys here; for instance, to reference an alternate config). Note this should work with existing VSCode prophet launch configurations.

```json
{
  "configurations": [
    {
      "type": "prophet",
      "request": "launch",
      "name": "Attach to Sandbox"
    },
    {
      "type": "prophet",
      "request": "launch",
      "name": "Attach to Sandbox abcd-002 alt Code Version",
      "sfcc": {
        "instance": "sandbox002",
        "code-version": "version2"
      }
    }
  ]
}
```

Then, start the debug adapter using the normal DAP commands. (see [nvim-dap][1] for more information on configuration and keybindings)

```vim
:lua require('dap').continue()
```


## Support

Open a github issue for any issues. DO NOT open an issue with Prophet unless you find a bug that can be reproduced using VSCode.

This project should not be treated as Salesforce Product. Customers and partners use this at-will with no expectation of roadmap, technical support, defect resolution, production-style SLAs.

This project is maintained by the Salesforce Community. Salesforce Commerce Cloud or Salesforce Platform Technical Support do not support this project or its setup.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.


[1]: https://github.com/mfussenegger/nvim-dap
[2]: https://github.com/SqrTT/prophet/
[3]: https://github.com/SalesforceCommerceCloud/sfcc-ci
[4]: https://github.com/SalesforceCommerceCloud/b2c-tools
[5]: https://github.com/rcarriga/nvim-dap-ui
