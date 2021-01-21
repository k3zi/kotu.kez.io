import _ from 'underscore';
import { gzip } from 'pako';

const helpers = {};

helpers.outputAccent = (word, accent) => {
    const smallrowKatakana = 'ァィゥェォヵㇰヶㇱㇲㇳㇴㇵㇶㇷㇷ゚ㇸㇹㇺャュョㇻㇼㇽㇾㇿヮ';
    let output = '';
    let mora = 0;
    let i = 0;
    while (i < word.length) {
        mora++;

        if (accent > 0 && mora === accent) {
            if (accent > 2) {
                // rise end
                output += "</marking>";
            }
            // drop start
            output += "<marking class='drop'>";
        }
        output += word.charAt(i);
        i++;

        while (i < word.length && smallrowKatakana.includes(word.charAt(i))) {
            output += word.charAt(i);
            i++;
        }

        // drop end
        if (accent > 0 && mora === accent) {
            output += "</marking>";
        }

        // heiban start
        if (accent === 0 && mora == 1 && i <= word.length) {
            output += "<marking class='overline'>"
        } else if (accent > 2 && mora === 1) {
            // rise start
            output += "<marking class='overline'>";
        }

        if (accent === 0 && i === word.length) {
            output += "</marking>";
        }
    }

    return output;
};

helpers.generateVisualSentenceElement = async function(content, textContent, isCancelled) {
    const sentenceResponse = await fetch(`/api/lists/sentence/parse`, {
        method: 'POST',
        body: await gzip(textContent),
        headers: {
            'Content-Encoding': 'gzip'
        }
    });
    let sentences = await sentenceResponse.json();
    const phrases = _.flatten(sentences.map(s => s.accentPhrases));
    if (isCancelled && isCancelled()) {
        return;
    }

    const contentElement = document.createElement('div');
    contentElement.innerHTML = content;

    const walker = document.createTreeWalker(contentElement, NodeFilter.SHOW_TEXT);
    let phraseIndex = 0;
    let didRemoveNode = false;
    do {
        didRemoveNode = false;
        let element = walker.currentNode;
        if (element.nodeType !== Node.TEXT_NODE) {
            continue;
        }

        const text = element.textContent;
        let newText = '';
        let startIndex = 0;
        let phrase = phrases[phraseIndex];
        let index = text.indexOf(phrase.surface, startIndex);
        while (index != -1) {
            if (phrase.isBasic) {
                newText += `<phrase><visual>${phrase.pronunciation}</visual><component>${phrase.surface}</component></phrase>`;
            } else {
                newText += `<phrase><visual>${helpers.outputAccent(phrase.pronunciation, phrase.pitchAccent.mora)}</visual>${phrase.components.map(c => {
                        return `<component data-headwords='${JSON.stringify(c.headwords)}' class='underline underline-pitch-${c.pitchAccents[0].descriptive} underline-${c.frequency}'>${c.ruby}</component>`;
                }).join('')}</phrase>`;
            }

            phraseIndex += 1;
            phrase = phrases[phraseIndex];
            if (phrase) {
                index = text.indexOf(phrase.surface, startIndex);
                startIndex += phrase.surface.length;
            } else {
                index = -1
            }
        }
        if (newText.length > 0) {
            const newElement = document.createElement('span');
            newElement.innerHTML = newText;
            element.before(newElement);

            // Have to go to the next phrase or else we lose our place.
            walker.nextNode();
            element.remove();
            didRemoveNode = true;
        }
    } while ((didRemoveNode || walker.nextNode()) && phraseIndex < phrases.length);
    return contentElement;
}

export default helpers;
