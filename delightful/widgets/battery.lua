-------------------------------------------------------------------------------
--
-- Battery widget for Awesome 3.5
-- Copyright (C) 2011-2016 Tuomas Jormola <tj@solitudo.net>
--
-- Licensed under the terms of GNU General Public License Version 2.0.
--
-- Description:
--
-- Shows a battery status indicator. Battery level is indicated as
-- a vertical progress bar and an icon indicator is shown next to it.
-- Clicking the icon launches an external application (if configured).
--
-- Widget extends vicious.widgets.bat from Vicious widget framework.
--
-- Widget tries to use icons from the package gnome-icon-theme
-- if available.
--
--
-- Configuration:
--
-- The load() function can be supplied with configuration.
-- Format of the configuration is as follows.
-- {
-- -- Name of the battery. Matches a file under the directory
-- -- /sys/class/power_supply/ and typically is "BATn" where n
-- -- is a number, most likely 0. 'BAT0' by default.
--        battery            = 'BAT2',
-- -- Command to execute when left-clicking the widget icon.
-- -- Empty by default.
--        command            = 'gnome-power-preferences',
-- -- Don't try to display any icons. Default is false (i.e. display icons).
--        no_icon            = true,
-- -- Height of the progress bar in pixels. Default is 19.
--        progressbar_height = 19,
-- -- Width of the progress bar in pixels. Default is 8.
--        progressbar_width  = 12,
-- -- How often update the widget data. Default is 20 seconds.
--        update_interval    = 30
-- }
--
--
-- Theme:
--
-- The widget uses following settings, colors and icons if available in
-- the Awesome theme.
--
-- theme.progressbar_height        - height of the battery charge progress bar in pixels
-- theme.progressbar_width         - width of the battery charge progress bar in pixels
-- theme.bg_widget                 - widget background color
-- theme.fg_widget                 - widget foreground color
-- theme.fg_center_widget          - widget gradient color, middle
-- theme.fg_end_widget             - widget gradient color, end
-- theme.delightful_battery_ac     - icon shown when the machine is connected to AC adapter
-- theme.delightful_battery_full   - icon shown when battery has 50%-99% charge
-- theme.delightful_battery_medium - icon shown when battery has 15%-49% charge
-- theme.delightful_battery_low    - icon shown when battery has less than 15% charge
-- theme.delightful_not_found      - icon shown when battery status is unknown
-- theme.delightful_error          - icon shown when critical error has occurred
--
-------------------------------------------------------------------------------

local awful      = require('awful')
local wibox      = require('wibox')
local beautiful  = require('beautiful')

local delightful = { utils = require('delightful.utils') }
local vicious    = require('vicious')

local pairs  = pairs
local string = { format = string.format }

module('delightful.widgets.battery')

local battery_config
local fatal_error
local icon_tooltip
local icon_files        = {}
local icon
local prev_icon

local config_description = {
	{
		name     = 'battery',
		required = true,
		default  = 'BAT0',
		validate = function(value)
			local status, errors = delightful.utils.config_string(value)
			if not status then
				return status, errors
			end
			local battery_path = string.format('/sys/class/power_supply/%s/status', value)
			if not awful.util.file_readable(battery_path) then
				return false, string.format('Battery not found: %s', value)
			end
			return true
		end
	},
	{
		name     = 'command',
		default  = 'gnome-power-preferences',
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
		default  = 8,
		validate = function(value) return delightful.utils.config_int(value) end
	},
	{
		name     = 'update_interval',
		required = true,
		default  = 20,
		validate = function(value) return delightful.utils.config_int(value) end
	},
}

local icon_description = {
	battery_ac     = { beautiful_name = 'delightful_battery_ac',     default_icon = 'battery-good-charging' },
	battery_full   = { beautiful_name = 'delightful_battery_full',   default_icon = 'battery-good'          },
	battery_medium = { beautiful_name = 'delightful_battery_medium', default_icon = 'battery-low'           },
	battery_low    = { beautiful_name = 'delightful_battery_low',    default_icon = 'battery-caution'       },
	not_found      = { beautiful_name = 'delightful_not_found',      default_icon = 'dialog-question'       },
	error          = { beautiful_name = 'delightful_error',          default_icon = 'dialog-error'          },
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
		battery_config = empty_config
		return
	end
	battery_config = config_data
end

-- Initalization
function load(self, config)
	handle_config(config)
	if fatal_error then
		delightful.utils.print_error('battery', fatal_error)
		return nil, nil
	end
	if not battery_config.no_icon then
		icon_files = delightful.utils.find_icon_files(icon_description)
	end
	if icon_files.battery_ac and icon_files.battery_full and icon_files.battery_medium and icon_files.battery_low and icon_files.not_found and icon_files.error then
		local buttons = awful.button({}, 1, function()
				if not fatal_error and battery_config.command then
					awful.util.spawn(battery_config.command, true)
				end
		end)
		icon = wibox.widget.imagebox()
		icon:buttons(buttons)
		icon_tooltip = awful.tooltip({ objects = { icon } })
	end

	local bg_color        = delightful.utils.find_theme_color({ 'bg_widget', 'bg_normal'                     })
	local fg_color        = delightful.utils.find_theme_color({ 'fg_widget', 'fg_normal'                     })
	local fg_center_color = delightful.utils.find_theme_color({ 'fg_center_widget', 'fg_widget', 'fg_normal' })
	local fg_end_color    = delightful.utils.find_theme_color({ 'fg_end_widget', 'fg_widget', 'fg_normal'    })

	local battery_widget = awful.widget.progressbar()
	if bg_color then
		battery_widget:set_border_color(bg_color)
		battery_widget:set_background_color(bg_color)
	end
	local color_args = fg_color
	local height = beautiful.progressbar_height or battery_config.progressbar_height
	local width  = beautiful.progressbar_width  or battery_config.progressbar_width
	if fg_color and fg_center_color and fg_end_color then
		color_args = {
			type = 'linear',
			from = { 0, 0 },
			to = { width, height },
			stops = {{ 0, fg_end_color }, { 0.5, fg_center_color }, { 1, fg_color }},
		}
	end
	battery_widget:set_color(color_args)
	battery_widget:set_width(width)
	battery_widget:set_height(height)
	battery_widget:set_vertical(true)
	vicious.register(battery_widget, vicious.widgets.bat, vicious_formatter, battery_config.update_interval, battery_config.battery)

	return { battery_widget }, { icon }
end

-- Vicious display formatter, also update widget tooltip and icon
function vicious_formatter(widget, data)
	-- update tooltip
	local unknown = false
	if icon_tooltip then
		local tooltip_text
		if fatal_error then
			tooltip_text = fatal_error
		elseif data[1] == '↯' then
			tooltip_text = 'Battery is charged'
		elseif data[1] == '+' then
			tooltip_text = string.format('Battery charge %d%% \n On AC power, %s until charged', data[2], data[3])
		elseif data[1] == '−' then
			tooltip_text = string.format('Battery charge %d%% \n On battery power, %s left', data[2], data[3])
		else
			tooltip_text = 'Battery status is unknown'
			unknown = true
		end
		icon_tooltip:set_text(string.format(' %s ', tooltip_text))
	end
	-- update icon
	if icon then
		local icon_file
		if fatal_error then
			icon_file = icon_files.error
		elseif unknown then
			icon_file = icon_files.not_found
		elseif data[1] == '+' then
			icon_file = icon_files.battery_ac
		elseif data[2] >= 50 and data[2] <= 100 then
			icon_file = icon_files.battery_full
		elseif data[2] >= 15 and data[2] < 50   then
			icon_file = icon_files.battery_medium
		elseif data[2] >= 0  and data[2] < 15   then
			icon_file = icon_files.battery_low
		end
		if icon_file and (not prev_icon or prev_icon ~= icon_file) then
			prev_icon = icon_file
			icon:set_image(icon_file)
		end
	end
	if fatal_error then
		return 0
	else
		return data[2]
	end
end
