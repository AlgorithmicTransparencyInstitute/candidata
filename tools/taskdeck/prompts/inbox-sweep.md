# Inbox sweep prompt

Paste this into a scheduled task (Claude Desktop scheduled task, a Claude Code
routine, or `/loop 30m` in a terminal session) that has the **Gmail**, **Slack**
and **Taskdeck** connectors enabled. It turns your inbox and Slack into ranked
Taskdeck tasks, and closes them again once you've replied.

---

You are triaging my email and Slack into my Taskdeck board. Use the taskdeck_* tools.

1. **Gmail.** Search threads from the last 3 days in my inbox that are not
   newsletters, receipts, calendar notifications or automated alerts. For each
   thread where someone is asking me for something (a reply, a decision, a
   document, a meeting) and the last message is not from me:
   - call `taskdeck_add_task` with `source: "email"`, `external_id` = the Gmail
     thread id, `from` = sender name, `link` = the Gmail thread URL,
     `title` = a short imperative ("Reply to Dana re: Q4 deck numbers"),
     `notes` = one or two lines on what is being asked and any deadline,
     `due` if a deadline is stated.
   - If the reply is straightforward, include a suggested reply in `draft`.
2. **Slack.** Search for messages in the last 3 days that mention me or are DMs
   to me, where someone asks me to do or decide something and I have not
   replied in the thread. Add each with `source: "slack"`, `external_id` = the
   message permalink, `link` = the permalink, `from` = "#channel · Person" or
   "DM · Person".
3. **Close the loop.** Call `taskdeck_list_tasks` for `source: "email"` and
   `source: "slack"`. For any task whose thread now has a reply from me, call
   `taskdeck_update_task` with `status: "done"`. If I replied but am now waiting
   on them, use `status: "waiting"`.
4. **Priority** (1-5): 5 = my boss, board members, funders or anything due
   within 24h; 4 = direct asks from colleagues or partners needed this week;
   3 = normal requests; 2 = FYI with a soft ask; 1 = someday. (Re-adding an
   existing task refreshes its notes/draft but keeps the priority and status I
   set on the board, so it is safe to pass priority every time.)

Do not send any email or Slack message. Finish with a one-line summary:
how many tasks you added, updated, and closed.
