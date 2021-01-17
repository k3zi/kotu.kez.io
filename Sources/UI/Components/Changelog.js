import React from 'react';
import UserContext from './Context/User';
import ReactMarkdown from 'react-markdown';
import gfm from 'remark-gfm';

class Component extends React.Component {
    render() {
        let markdown = `# Changelog
#### 2021/1/16
- Added this changelog ;)
- Added Plex as an option of capturing media.
- TODO: HLS streaming does not currently work with Chrome for some reason.
- TODO: Add breadcrumbs so users can navigate Plex menu without reloading.
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
