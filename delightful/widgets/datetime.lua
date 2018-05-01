-------------------------------------------------------------------------------
--
-- Date and time widget with calendar popup display for Awesome 3.5
-- Copyright (C) 2011-2016 Tuomas Jormola <tj@solitudo.net>
--
-- Licensed under the terms of GNU General Public License Version 2.0.
--
-- Description:
--
-- This widget displays date and time and when the mouse cursor
-- hovers over the widget, a calendar for current month is displayed.
-- You can navigate between months by using mouse scroll wheel.
--
-- Widget uses calendar2 module by Bzed.
-- http://awesome.naquadah.org/wiki/Calendar_widget#Module_for_3.4
--
--
-- Configuration:
--
-- The load() function can be supplied with configuration.
-- Format of the configuration is as follows.
-- {
-- -- Date/time format string passed to awful.textclock. Empty by default,
-- -- in which case the default format of the latter is used.
--           clock_format = ' %R ',
-- }
--
--
-- Theme:
--
-- The widget uses following colors if available in the Awesome theme.
--
-- theme.fg_focus - text color of the current date in calendar
-- theme.bg_focus - background color of the current date in calendar
--
-------------------------------------------------------------------------------

local awful     = require('awful')
local beautiful = require('beautiful')

local delightful = { utils = require('delightful.utils') }

local calendar2 = require('calendar2')

local string = { format = string.format }

module('delightful.widgets.datetime')

local datetime_config
local fatal_error

local config_description = {
    {
        name = 'clock_format',
        validate = function(value) return delightful.utils.config_string(value) end
    },
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
        datetime_config = empty_config
        return
    end
    datetime_config = config_data
end

function load(self, config)
    handle_config(config)
    if fatal_error then
        delightful.utils.print_error('datetime', fatal_error)
	return nil, nil
    end
    local widget = awful.widget.textclock(datetime_config.clock_format)
    local calendar_format = '%s'
    if beautiful.fg_focus and beautiful.bg_focus then
        calendar_format = string.format('<span color="%s" background="%s">%%s</span>',
                beautiful.fg_focus, beautiful.bg_focus)
    end
    calendar2.addCalendarToWidget(widget, calendar_format)
    return { widget } -- no icon
end
