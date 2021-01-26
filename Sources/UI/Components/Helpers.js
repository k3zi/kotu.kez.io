import _ from 'underscore';
import { gzip } from 'pako';
import gfm from 'remark-gfm';
import katex from 'rehype-katex';
import markdown from 'remark-parse';
import math from 'remark-math';
import remark2rehype from 'remark-rehype';
import stringify from 'rehype-stringify';
import unified from 'unified';

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

helpers.generateVisualSentenceElement = async (content, textContent, isCancelled) => {
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
};

helpers.htmlForFrequency = async (sentence) => {
    const html = `<div class='page visual-type-showFrequency'><span>${sentence}</span></div>`;
    return await helpers.generateVisualSentenceElement(html, sentence);
};

helpers.htmlForPitch = async (sentence) => {
    const html = `<div class='page visual-type-showPitchAccent'><span>${sentence}</span></div>`;
    return await helpers.generateVisualSentenceElement(html, sentence);
};

helpers.htmlForField = (field) => {
    return unified()
        .use(markdown)
        .use(gfm)
        .use(math)
        .use(remark2rehype)
        .use(katex)
        .use(stringify)
        .processSync(field);
}

helpers.htmlForCard = async (baseHTML, fieldValues, autoplay) => {
    let result = baseHTML;
    // Replace fields.
    for (let fieldValue of fieldValues) {
        const fieldName = fieldValue.field.name;
        const value = helpers.htmlForField(fieldValue.value);
        const replace = `{{${fieldName}}}`;
        result = result.replace(new RegExp(replace, 'g'), value);
    }

    // Handle media for front / back.
    let regex = /\[audio: ([A-Za-z0-9-]+)\]/gmi;
    let subst = `<audio controls${autoplay ? ' autoplay' : ''}><source src="/api/media/audio/$1" type="audio/x-m4a"></audio>`;
    result = result.replace(regex, subst);

    regex = /\[frequency: (.*)\]/mi;
    let match;
    while ((match = regex.exec(result)) !== null) {
        const sentence = match[1];
        const element = await helpers.generateHTMLForFrequency(sentence);
        result = result.substring(0, match.index) + element.innerHTML + result.substring(match.index + match[0].length);
    }

    regex = /\[pitch: (.*)\]/mi;
    while ((match = regex.exec(result)) !== null) {
        const sentence = match[1];
        const element = await helpers.generateHTMLForPitch(sentence);
        result = result.substring(0, match.index) + element.innerHTML + result.substring(match.index + match[0].length);
    }
    return result;
};

export default helpers;
