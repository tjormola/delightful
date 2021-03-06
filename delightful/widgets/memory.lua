-------------------------------------------------------------------------------
--
-- Memory widget for Awesome 3.5
-- Copyright (C) 2011-2016 Tuomas Jormola <tj@solitudo.net>
--
-- Licensed under the terms of GNU General Public License Version 2.0.
--
-- Description:
--
-- Displays memory and swap usage statistics as a vertical progress bars.
-- Also displays a memory icon next to the memory graph. Clicking the icon
-- launches an external application (if configured).
--
-- Widget extends vicious.widgets.mem from Vicious widget framework.
--
-- Widget tries to use an icon from the package mate-sensors-applet-common
-- if available.
--
--
-- Configuration:
--
-- The load() function can be supplied with configuration.
-- Format of the configuration is as follows.
-- {
-- -- Command to execute when left-clicking the widget icon.
-- -- Empty by default.
--        command            = 'gnome-system-monitor',
-- -- Don't try to display any icons. Default is false (i.e. display icons).
--        no_icon            = true,
-- -- Height of the progress bar in pixels. Default is 19.
--        progressbar_height = 19,
-- -- Width of the progress bar in pixels. Default is 12.
--        progressbar_width  = 12,
-- -- How often update the widget data. Default is 10 second.
--        update_interval    = 20
-- }
--
--
-- Theme:
--
-- The widget uses following settings, colors and icons if available in
-- the Awesome theme.
--
-- theme.progressbar_height - height of the memory usage progress bar in pixels
-- theme.progressbar_width  - width of the memory usage progress bar in pixels
-- theme.bg_widget          - widget background color
-- theme.fg_widget          - widget foreground color
-- theme.fg_center_widget   - widget gradient color, middle
-- theme.fg_end_widget      - widget gradient color, end
-- theme.delightful_mem     - icon shown next to the memory progress bars
--
-------------------------------------------------------------------------------

local awful      = require('awful')
local wibox      = require('wibox')
local beautiful  = require('beautiful')

local delightful = { utils = require('delightful.utils') }
local vicious    = require('vicious')

local io       = { lines = io.lines }
local math     = { floor = math.floor }
local pairs    = pairs
local string   = { format = string.format }
local table    = { insert = table.insert }
local tonumber = tonumber

module('delightful.widgets.memory')

-- Helper
function is_swap_available()
    for line in io.lines('/proc/meminfo') do
        local total_swap = tonumber(line:match('^SwapTotal:%s+(%d+)%s+kB$'))
        if total_swap and total_swap > 0 then
            return true
        end
    end
    return false
end

local memory_config
local fatal_error
local icon_tooltip
local has_swap = is_swap_available()

local config_description = {
    {
        name     = 'command',
        validate = function(value) return delightful.utils.config_string(value) end
    },
    {
        name     = 'no_icon',
        validate = function(value) return delightful.utils.config_boolean(value) end
    },
    {
        name     = 'progressbar_height',
        required = true,
        default  = 19,
        validate = function(value) return delightful.utils.config_int(value) end
    },
    {
        name     = 'progressbar_width',
        required = true,
        default  = 12,
        validate = function(value) return delightful.utils.config_int(value) end
    },
    {
        name     = 'update_interval',
        required = true,
        default  = 10,
        validate = function(value) return delightful.utils.config_int(value) end
    },
}

local icon_description = {
    memory = { beautiful_name = 'delightful_mem', default_icon = 'mate-sensors-applet-memory' },
}

-- Configuration handler
function handle_config(user_config)
    local empty_config = delightful.utils.get_empty_config(config_description)
    if not user_config then
        user_config = empty_config
    end
    local config_data = delightful.utils.normalize_config(user_config, config_description)
    local validation_errors = delightful.utils.validate_config(config_data, config_description)
    if validation_errors then
        fatal_error = 'Configuration errors: \n'
        for error_index, error_entry in pairs(validation_errors) do
            fatal_error = string.format('%s %s', fatal_error, error_entry)
            if error_index < #validation_errors then
                fatal_error = string.format('%s \n', fatal_error)
            end
        end
        memory_config = empty_config
        return
    end
    memory_config = config_data
end

-- Initalization
function load(self, config)
    handle_config(config)
    if fatal_error then
        delightful.utils.print_error('memory', fatal_error)
        return nil, nil
    end
    local icon
    local icon_files
    if not memory_config.no_icon then
        icon_files = delightful.utils.find_icon_files(icon_description)
    end
    local icon_file = icon_files and icon_files.memory
    if icon_file then
        local buttons = awful.button({}, 1, function()
            if not fatal_error and memory_config.command then
                awful.util.spawn(memory_config.command, true)
            end
        end)
        icon = wibox.widget.imagebox()
        icon:buttons(buttons)
        icon:set_image(icon_file)
        icon_tooltip = awful.tooltip({ objects = { icon } })
    end
    local icons = { icon }

    local bg_color        = delightful.utils.find_theme_color({ 'bg_widget', 'bg_normal'                     })
    local fg_color        = delightful.utils.find_theme_color({ 'fg_widget', 'fg_normal'                     })
    local fg_center_color = delightful.utils.find_theme_color({ 'fg_center_widget', 'fg_widget', 'fg_normal' })
    local fg_end_color    = delightful.utils.find_theme_color({ 'fg_end_widget', 'fg_widget', 'fg_normal'    })

    local memory_widget = awful.widget.progressbar()
    if bg_color then
        memory_widget:set_background_color(bg_color)
        memory_widget:set_border_color(bg_color)
    end
    local color_args = fg_color
    local height = beautiful.progressbar_height or memory_config.progressbar_height
    local width  = beautiful.progressbar_width  or memory_config.progressbar_width
    if fg_color and fg_center_color and fg_end_color then
        color_args = {
            type = 'linear',
            from = { width / 2, 0 },
            to = { width / 2, height },
            stops = {{ 0, fg_end_color }, { 0.5, fg_center_color }, { 1, fg_color }},
        }
    end
    memory_widget:set_color(color_args)
    memory_widget:set_width(width)
    memory_widget:set_height(height)
    memory_widget:set_vertical(true)
    vicious.register(memory_widget, vicious.widgets.mem, vicious_formatter_memory, memory_config.update_interval)
    local widgets = { memory_widget }


    if has_swap then
        local swap_widget = awful.widget.progressbar()
        if bg_color then
            swap_widget:set_background_color(bg_color)
            swap_widget:set_border_color(bg_color)
        end
        swap_widget:set_color(color_args)
        swap_widget:set_width(width)
        swap_widget:set_height(height)
        swap_widget:set_vertical(true)
        vicious.register(swap_widget, vicious.widgets.mem, vicious_formatter_swap, memory_config.update_interval)
        table.insert(widgets, swap_widget)
    end

    vicious.cache(vicious.widgets.mem)

    return widgets, icons
end

-- Vicious display formatter for memory graph, also update widget tooltip
function vicious_formatter_memory(widget, data)
    if icon_tooltip then
        local swap_string = ''
        if has_swap then
            swap_string = 'and swap '
        end
        local tooltip_text = string.format(' Memory %susage statistics \n Current memory usage: %d%% (%dMB out of %dMB) ', swap_string, data[1], data[2], data[3])
        if has_swap then
            tooltip_text = string.format('%s\n Current swap usage: %d%% (%dMB out of %dMB) ', tooltip_text, data[5], data[6], data[7])
        end
        icon_tooltip:set_text(tooltip_text)
    end
    return data[1]
end

-- Vicious display formatter for swap graph
function vicious_formatter_swap(widget, data)
    return data[5]
end
