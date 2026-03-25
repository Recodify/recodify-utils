Target: play-reborn.html


1. make it clearer what connection is active when working with a query, currently it's not easy to tell.
2. ![query_length](query_length.png) - when the query being executed is long, it takes up a huge amount of the veritical space and pushses results way down the screen. We can tackle this in a few ways: reduce font size, remove newlines, display a truncated query with ..., not sure this here at all given it's already in the acton history and query editor
3. ![horizontal scroll](horizontal-scroll.png) - when the query results table is wide, it CAN be horizontally scrolled, however the scroll bar lives down below the action history so can be both hard to spot and also scrolls the action history, which isn't really whats intended.
4. the bg color of the results pane seems to be a bit arbitary/inconsistent:
[alt text](color3.png)![alt text](color2.png)![alt text](color1.png) why is this?
5. Add option to generate a select with all the column names in addition to this:
```javascript
{
            icon: '≡',
            label: is_view ? 'Generate SELECT from view' : 'Generate SELECT',
            onClick: () => insertTextIntoEditor(`SELECT * FROM ${database}.${table} LIMIT 100;`)
        }
```
6. ability to colapse/expand all ![connection-header](connection-header.png) items in the navigator tree for a given connection, to be aded alongside the current three dot menu