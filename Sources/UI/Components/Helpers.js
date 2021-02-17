import _ from 'underscore';
import { gzip } from 'pako';
import gfm from 'remark-gfm';
import katex from 'rehype-katex';
import markdown from 'remark-parse';
import math from 'remark-math';
import remark2rehype from 'remark-rehype';
import stringify from 'rehype-stringify';
import unified from 'unified';
import raw from 'rehype-raw';
import slug from 'rehype-slug';
import link from 'rehype-autolink-headings';
import breaks from 'remark-breaks';

const smallHiragana = 'ぁぃぅぇぉゃゅょゎ';
const smallrowKatakana = 'ァィゥェォヵㇰヶㇱㇲㇳㇴㇵㇶㇷㇷ゚ㇸㇹㇺャュョㇻㇼㇽㇾㇿヮ';
const helpers = {};

helpers.removeYouon = (text) => {
    return text.split('').filter(c => !smallHiragana.includes(c) && !smallrowKatakana.includes(c)).join('');
}

helpers.digest = async (message) => {
    const msgUint8 = new TextEncoder().encode(message);
    const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    return hashHex;
};

helpers.addLiveEventListeners = (selector, event, handler) => {
    document.querySelector("body").addEventListener(event, (evt) => {
        let target = evt.target;
        while (target) {
            var isMatch = target.matches(selector);
            if (isMatch) {
                handler(evt, target);
               return;
           }
           target = target.parentElement;
       }
   }, true);
};

helpers.outputAccent = (word, accent) => {
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

        while (i < word.length && (smallrowKatakana.includes(word.charAt(i)) || smallHiragana.includes(word.charAt(i)))) {
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

helpers.generateManualPitchElement = (rawText) => {
    const phrases = rawText.split('・');
    const text = phrases.map(p => {
        let components = p.split('／');
        for (let [i, c] of components.entries()) {
            if (i > 0) {
                const prev = components[i - 1];
                if (prev.length == 0) { continue; }
                const lastChar = prev[prev.length - 1];
                components[i - 1] = prev.slice(0, -1);
                components[i] = `${lastChar}${components[i]}`
            }
        }
        components = components.filter(c => c.length > 0);
        return components.map(c => {
            let accent = helpers.removeYouon(c).indexOf('＼');
            if (accent < 0) {
                accent = 0;
            }
            const clean = c.split('＼').join('');
            return helpers.outputAccent(clean, accent);
        }).join('');
    }).map(p => `<phrase><visual>${p}</visual></phrase>`).join(' ');
    return `<span class='visual-type-showPitchAccentDrops'>${text}</span>`;
}

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

helpers.textFromHTML = (html) => {
    const span = document.createElement('span');
    span.innerHTML = html;
    return span.textContent || span.innerText;
}

helpers.htmlForFrequency = async (sentence) => {
    const html = `<span class='visual-type-showFrequency'><span>${sentence}</span></span>`;
    return await helpers.generateVisualSentenceElement(html, helpers.textFromHTML(sentence));
};

helpers.htmlForPitch = async (sentence) => {
    const html = `<span class='visual-type-showPitchAccent'><span>${sentence}</span></span>`;
    return await helpers.generateVisualSentenceElement(html, helpers.textFromHTML(sentence));
};

helpers.parseMarkdown = (rawText) => {
    let text = rawText.replace(/(^(\r\n|\n|\r)$)|(^(\r\n|\n|\r))|^\s*$/gm, '\n\n<br />\n\n');
    let regex = /\[mpitch: (.*?)\]/mi;
    let match;
    while ((match = regex.exec(text)) !== null) {
        const sentence = match[1];
        const html = helpers.generateManualPitchElement(sentence);
        text = text.substring(0, match.index) + html + text.substring(match.index + match[0].length);
    }

    regex = /\|\|(.*?)\|\|/mi;
    while ((match = regex.exec(text)) !== null) {
        const s = match[1];
        const id = Math.random().toString(36).slice(-10);
        const html = `<span class='spoiler'>${s}</span>`;
        text = text.substring(0, match.index) + html + text.substring(match.index + match[0].length);
    }

    regex = /\[audio: ([A-Za-z0-9-]+)\]/gmi;
    let subst = `<audio controls><source src="/api/media/audio/$1" type="audio/x-m4a"></audio>`;
    text = text.replace(regex, subst);
    return unified()
        .use(markdown)
        .use(breaks)
        .use(gfm)
        .use(math)
        .use(remark2rehype, {
            allowDangerousHtml: true
        })
        .use(raw)
        .use(katex)
        .use(slug)
        .use(link, {
            content: {
                type: 'element',
                tagName: 'span',
                properties: {
                    className: ['bi', 'bi-link-45deg']
                },
                children: []
            },
            properties: {
                className: ['autolink']
            }
        })
        .use(stringify)
        .processSync(text).contents;
}

helpers.htmlForCard = async (baseHTML, options) => {
    const { fieldValues, autoPlay, answers, answersType, showClozeDeletion, clozeDeletionIndex } = options;
    let result = baseHTML;
    // Replace fields.
    for (let fieldValue of fieldValues) {
        const fieldName = fieldValue.field.name;
        const value = fieldValue.value;
        const replace = `{{${fieldName}}}`;
        result = result.replace(new RegExp(replace, 'g'), value);
    }

    if (clozeDeletionIndex && clozeDeletionIndex > 0) {
        if (showClozeDeletion) {
            result = result.replace(new RegExp(`\{\{c${clozeDeletionIndex}::(.*?)(::(.*?))?\}\}`, 'g'), `<span class='cloze-deletion'>$1</span>`);
        } else {
            result = result.replace(new RegExp(`\{\{c${clozeDeletionIndex}::(.*?)::(.*?)\}\}`, 'g'), `<span class='cloze-deletion'>[$2]</span>`);
            result = result.replace(new RegExp(`\{\{c${clozeDeletionIndex}::(.*?)\}\}`, 'g'), `<span class='cloze-deletion'>[...]</span>`);
        }
    }
    result = result.replace(new RegExp(`\{\{c\\d::(.*?)(::.*?)?\}\}`, 'g'), '$1');

    // Handle media for front / back.
    let regex = /\[audio: ([A-Za-z0-9-]+)\]/gmi;
    let subst = `<audio controls${autoPlay ? ' autoplay' : ''}><source src="/api/media/audio/$1" type="audio/x-m4a"></audio>`;
    result = result.replace(regex, subst);

    regex = /\[frequency: (.*?)\]/mi;
    let match;
    while ((match = regex.exec(result)) !== null) {
        const sentence = match[1];
        const element = await helpers.htmlForFrequency(sentence);
        result = result.substring(0, match.index) + element.innerHTML + result.substring(match.index + match[0].length);
    }

    regex = /\[pitch: (.*?)\]/mi;
    while ((match = regex.exec(result)) !== null) {
        const sentence = match[1];
        const element = await helpers.htmlForPitch(sentence);
        result = result.substring(0, match.index) + element.innerHTML + result.substring(match.index + match[0].length);
    }

    regex = /\[type: (.*?)\]/mi;
    while ((match = regex.exec(result)) !== null) {
        const answer = match[1];
        const digest = await helpers.digest(answer);
        let html = '';
        if (answersType === 'none') {
            html = `<input type='text' class='form-control card-field-answer' placeholder='Enter answer' data-key='${digest}'>`;
        } else {
            const answered = answers[digest];
            const answeredDigest = await helpers.digest(answered);
            const correct = answeredDigest === digest;
            const value = answersType === 'show' ? answer : answered;
            html = `<div class="input-group">
                <input type='text' class='form-control' value='${value}' disabled readonly>
                <span class="input-group-text">
                    ${correct ? `<i class='bi bi-check fs-3 text-success' />` : `<i class='bi bi-x fs-3 text-danger' />`}
                </span>
            </div>`;
        }
        result = result.substring(0, match.index) + html + result.substring(match.index + match[0].length);
    }

    return helpers.parseMarkdown(result);
};

helpers.scrollToHash = () => {
    const id = window.location.hash.substr(1);
    if (!id) { return; }
    const anchor = document.getElementById(id);
    if (!anchor) { return; }
    anchor.scrollIntoView();
};

export default helpers;
