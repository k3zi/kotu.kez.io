import React from 'react';
import UserContext from './Context/User';
import ReactMarkdown from 'react-markdown';
import gfm from 'remark-gfm';

class Component extends React.Component {
    render() {
        let markdown = `# Changelog
#### 2021/4/3
- **[anki]:** add modifiable keybindings
- **[anki]:** speed up performance
- **[anki]:** add shuffle button for decs
---
#### 2021/3/28
- **[reader]:** allow reading with media
- **[transcribe]:** allow auto-syncing text
- **[all]:** add showing word status as an experimental setting
- **[dictionaries]:** allow sorting dictionaries
- **[tests]:** add pitch accent test for counters
---
#### 2021/3/15
- **[tests]:** add pitch accent test for names
---
#### 2021/3/14
- **[dictionaries]:** remove duplicate entries in search results
- **[ui]:** add setting for preferring horizontal text
---
#### 2021/3/11
- **[dictionaries]:** improve dictionary upload dialogue
- **[media.youtube]:** fix bug with auto-generated subtitles
- **[ui]:** allow dark mode to be explicitly set
---
#### 2021/3/6
- **[anki]:** add option move note to a different deck
---
#### 2021/3/2
- **[ui]:** add option to settings to prefer a stronger color contrast (currently only adjusted in a few places; use the feedback form to help identify other places that can be fixed)
---
#### 2021/2/27
- **[anki]:** add context menu for quick access to plugins
- **[ui]:** add dark style to dropdown menus when in dark mode
---
#### 2021/2/26
- **[anki]:** add ability to edit notes
---
#### 2021/2/22
- **[media.player]:** add pitch to sentences
---
#### 2021/2/22
- **[media.player]:** caches subtitle requests
- **[search]:** add option to search for subtitles
---
#### 2021/2/21
- **[anki]:** offset grades to prevent log of zero
- **[anki]:** small superfluous range adjustments in algorithm
- **[anki]:** fix bug were deck creation would crash due to default values not getting sent back
---
#### 2021/2/20
- **[anki]:** fix deleting fields with previous values
- **[anki]:** add option to change review order
- **[media.reader]:** fix content with mismatching parsed nodes causing annotations to stop midway through
---
#### 2021/2/18
- **[media.player]:** add support for viewing / capturing YouTube subtitles
- **[media.player]:** add support for auto generated subtitles
- **[media.player]:** fix some bugs for copying text
---
#### 2021/2/17
- **[mpitch]:** fix some space issues
- **[mpitch]:** add functionality to mark mora as silenced by placing a full width backtick (｀) before it
---
#### 2021/2/16
- Added cloze deletion cards.
---
#### 2021/2/13
- Add mpitch plugin. Ex: \`[mpitch: あした＼は・がっこうに・いくつもりで＼す]\`
---
#### 2021/2/12
- Articles: Added.
---
#### 2021/2/10
- MeCab: Fix accent for names.
---
#### 2021/2/2
- Add ability to download audio fragments from transcription projects.
---
#### 2021/1/27
- Add \`[type: ]\` feature to allow you to type in an answer on the front of a card and check it on the back.
- Allow markdown when editing the note types.
---
#### 2021/1/26
- Show preview on note creation.
- Support a small subset of LaTeX inside of card fields (using KaTeX).
- Support markdown formatting inside of card fields.
- Remember the last used deck / note type for future cards.
- Allow hiding the field preview.
---
#### 2021/1/25
- Fix note type deletion.
- Fix spelling error.
---
#### 2021/1/23
- Use fastest link for Plex videos.
---
#### 2021/1/22
- Add more pitch accent combination kinds.
- Use EDict2 to back finding compound nouns.
---
#### 2021/1/21
- Rewrite MeCab parser to better handle compounds and to support accent phrases.
- Add pitch drop option to reader.
---
#### 2021/1/19
- Added option for furigana based on frequency on the Reader page.
- Added click to display dictionary entries feature to Reader.
- Add settings page.
- Add option to hide card note form.
---
#### 2021/1/18
- Add ability to add card types.
---
#### 2021/1/17
- Added browser for Anki notes.
- Added start of help page.
- Added feedback form.
- Added \`[frequency: ]\` syntax for showing the frequency of a sentence.
- Added \`[pitch: ]\` syntax for showing the word-level pitch accent of a sentence.
- Added ability to update the requested forgetting index of decks.
- Adjusted the default requested forgetting index to 8.
---
#### 2021/1/16
- Added this changelog ;)
- Added Plex as an option of capturing media.
- Fixed 'Capture' button so it works with mobile devices.
- Fixed support for Chrome streaming by using the dash protocol.
- Added breadcrumbs to Plex browsing.
- Added checkmark to watched Plex media.
- Added basic dark mode.
---
#### 2021/1/13
- Added pitch accent (supplied by MeCab) to the Reader.
---
#### 2021/1/11
- Added a reader that can show the frequency of words from an article or text.
---
#### 2021/1/9
- Added word lists. Track words that you come across and search for. Tracks lookups and marks words as already read when you add a sentence with those words.
---
#### 2021/1/7
- Add ability to invite users to all of you projects
---
#### 2021/1/6
- Add pitch accent minimal pair test.
- Add live chat to projects. (Chat is not saved)
- Add ability to edit fragments.
---
`;
        return (<ReactMarkdown plugins={[gfm]} children={markdown} />);
    }
}

export default Component;
