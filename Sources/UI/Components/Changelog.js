import React from 'react';
import UserContext from './Context/User';
import ReactMarkdown from 'react-markdown';
import gfm from 'remark-gfm';

class Component extends React.Component {
    render() {
        let markdown = `# Changelog
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
