## Purpose

a DSL/spec to specify appointments/habits/recurring events etc. to provide the user a per-day view of what they should do on a given day. 

## General

- we are using a positional notation
- each line (/item) must start with a "-marked string naming the item
- an item must have at least one primaryType
- a reserved keyword is followed by 0 to n properties pertaining to that keyword
- reserved keywords are made up from a-z (small case, no numbers or dashes) 

- in the later following frontend, we will have a view for items that "need attention", which will include invalid items, but also items marked as needing attention, such as by the `reconsider` keyword

- a paranthesis wrapped string at the end of an item is used for changing data, such as a mark when this item was last generated

- in the later frontend, some items may be marked "finished", this is semantically relevant

## primaryType options

(this list will likely be attendted)



### goal

a long-term goal that cannot, in that sense, be finished

### weekly

an event recurring every week. must be followed by a weekday.

## Other Reserved Keywords

### prio

must be followed by a number value.
Will later be used to sort items, or weigh random picks

### reconsider

must be followed by two arguments, time unit and number.

### raincheck

valid for dated events. means that if task is not marked finished it will show up again on the next day.

If a number follows, it will show up that many days in the future (instead of on the next day)

### finishable


This item can meaningfully be finished, which is semantically relevant in the frontend.

### next

only valid in the end parenthesis.
must be followed by a string marking an action to be taken next

### iterable

must be followed by time unit, number, and then optionally a float from 0-1

## Data Types

- dates are formatted yy-mm-dd or mm-dd or dd
- in some contexts we use a single letter time unit: d for day, m for month, y for year, w for week, h for hour
- weekdays are referred to as: mo tu we th fr sa su