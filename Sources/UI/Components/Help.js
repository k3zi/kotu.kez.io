import React from 'react';
import UserContext from './Context/User';
import ReactMarkdown from 'react-markdown';
import gfm from 'remark-gfm';

class Component extends React.Component {
    render() {
        let markdown = `# Help
---

### Transcribe
Add subtitles to YouTube videos. Practice transcription or translation or use for a project. Collaborate with others in real time. Work on multiple translations at the same time.

---
### Anki
The Anki module has no direct relation with Anki the software.
It's just named that way because other names didn't sound cool enough ;).
Although a lot of the structure is based off of Anki.
The scheduler used in this app is a rewrite of Sweet Memo 15 which was an attempt at implementing a rough version of Super Memo 15 (SM-15).
Theoretically it should be miles better than SM-2 (which is the version Anki uses) but there is no data to support this in the case of Sweet Memo so **use it at your own risk**.

#### Getting Started
To get started you should create a deck and then add a note type if you haven't already.
This system basically mirrors Anki.
Once you create a note type you should notice two fields automatically get added to the note type.
Feel free to add / delete fields as you feel necessary. You may also add new card types (which end up being the cards that get generated) or modify the layout of the cards. Any changes that you make are automatically saved in real time.

#### Formatting
The Anki module supports these commands:


\`{{FieldName}}\`
- Use to display a specific field value (replacing FieldName with the name of the field).

\`[audio: UUID]\`
- Presents audio controls for the audio file specified.
- UUID is the ID of the file upload.
- These can currently be created by using the YouTube / Plex media page to capture audio from media sources. (Manual file upload coming soon).
- Auto play is enabled on both sides of the card but if you use {{FrontSide}} on the back side then any audio on the front will not auto play.


\`[frequency: 恥の多い生涯を送ってきました。]\`
- Labels the frequency of words using underlines.


\`[pitch: 恥の多い生涯を送ってきました。]\`
- Labels the pitch accent of words using underlines.


\`[kanji: 恥]\` **(Coming Soon)**
- Displays the stroke order for the specified kanji.

---

### Lists

---

### Media

---

### Tests

---
`;
        return (<ReactMarkdown plugins={[gfm]} children={markdown} />);
    }
}

export default Component;
