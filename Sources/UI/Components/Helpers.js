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

// helpers.fetch = async (url, options) => {
//     const options = options || {};
//     options.headers = options.headers || {};
//     options.headers['X-Kotu-Api-Version']
//     return fetch(url, {})
// }

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

helpers.randomString = (length) => {
    let text = '';
    const charset = "abcdefghijklmnopqrstuvwxyz0123456789";
    for (var i = 0; i < length; i++) {
        text += charset.charAt(Math.floor(Math.random() * charset.length));
    }

  return text;
};

helpers.addLiveEventListeners = (selector, event, handler, useCapture, querySelector) => {
    document.querySelector((typeof querySelector === 'undefined') ? 'body' : querySelector).addEventListener(event, (evt) => {
        let target = evt.target;
        while (target) {
            var isMatch = target.matches(selector);
            if (isMatch) {
                return handler(evt, target);
           }
           target = target.parentElement;
       }
   }, (typeof useCapture === 'undefined') ? true : useCapture);
};

helpers.outputAccent = (word, accent) => {
    let output = '';
    let mora = 0;
    let i = 0;
    while (i < word.length) {
        mora++;
        let silenced = false;

        if (accent > 0 && mora === accent) {
            if (accent > 2) {
                // rise end
                output += "</marking>";
            }
            // drop start
            output += "<marking class='drop'>";
        }
        if (word.charAt(i) === '｀') {
            i++;
            silenced = true;
            if ((i+1) < word.length && (smallrowKatakana.includes(word.charAt(i+1)) || smallHiragana.includes(word.charAt(i+1)))) {
                output += "<silenced class='wide'>";
            } else {
                output += '<silenced>';
            }
        }
        output += word.charAt(i);
        i++;

        // add any small youon sounds
        while (i < word.length && (smallrowKatakana.includes(word.charAt(i)) || smallHiragana.includes(word.charAt(i)))) {
            output += word.charAt(i);
            i++;
        }

        if (silenced) {
            output += '</silenced>';
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

helpers.outputAccentPlainText = (word, accent) => {
    const smallrowKatakana = 'ァィゥェォヵㇰヶㇱㇲㇳㇴㇵㇶㇷㇷ゚ㇸㇹㇺャュョㇻㇼㇽㇾㇿヮ';
    let output = '';
    let mora = 0;
    let i = 0;
    while (i < word.length) {
        output += word.charAt(i);

        i++;
        mora++;

        while (i < word.length && smallrowKatakana.includes(word.charAt(i))) {
            output += word.charAt(i);
            i++;
        }

        if (mora === accent) {
            output += "＼"
        }
    }

    return output;
};

helpers.generateManualPitchElement = (rawText) => {
    const regex = /([^・\u3040-\u309f\u30a0-\u30ff\uff00-\uff9f]*)([／｀　 ＼\u3040-\u309f\u30a0-\u30fa\u30fc-\u30ff\uff00-\uff9f]+)([^・\u3040-\u309f\u30a0-\u30ff\uff00-\uff9f]*)/gm;
    let match;
    let result = '';
    while ((match = regex.exec(rawText)) !== null) {
        if (match.index === regex.lastIndex) {
            regex.lastIndex++;
        }
        const preMiscText = match[1];
        const text = match[2];
        const postMiscText = match[3];

        let components = text.split('／');
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
        const parsedText = components.map(c => {
            let accent = helpers.removeYouon(c).indexOf('＼');
            if (accent < 0) {
                accent = 0;
            }
            const clean = c.split('＼').join('');
            return helpers.outputAccent(clean, accent);
        }).join('');
        result += `${preMiscText}<phrase><visual>${parsedText}</visual></phrase>${postMiscText}`;
    }
    result = result.replace(/<\/phrase><phrase/g, '</phrase><space></space><phrase');
    return `<span class='visual-type-showPitchAccentDrops'>${result}</span>`;
}

helpers.parseSentences = async (textContent) => {
    const sentenceResponse = await fetch(`/api/dictionary/parse`, {
        method: 'POST',
        body: await gzip(textContent),
        headers: {
            'Content-Encoding': 'gzip'
        }
    });
    return await sentenceResponse.json();
};

helpers.generateVisualSentenceElement = async (content, textContent, isCancelled) => {
    let sentences = await helpers.parseSentences(content, textContent);
    if (isCancelled && isCancelled()) {
        return;
    }

    return await helpers.generateVisualSentenceElementFromSentences(sentences, content, {}, isCancelled);
};

helpers.generateVisualSentenceElementFromSentences = async (sentences, content, options, isCancelled) => {
    const contentElement = document.createElement('div');
    contentElement.innerHTML = content;

    if (!sentences || sentences.length === 0) {
        return contentElement;
    }

    sentences = sentences.map(s => s.accentPhrases);
    let phrases = sentences.shift() || [];
    const subtitles = (options.subtitles || []).sort((a, b) => a.startTime - b.startTime);
    subtitles.forEach(s => {
        s.cleanText = s.text.replace(/[\s「」]/g,'');
    });
    let subtitle = subtitles.shift();
    let buildUpSubtitle = '';

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
        let index = text.indexOf(phrase.surface.charAt(0), startIndex);
        while (index != -1) {
            const skipPost = false;
            const cleanSurface = phrase.surface.replace(/[\s「」]/g,'');
            if (!subtitle || ((buildUpSubtitle.replace(/\s/g,'').length > 0 || phrase.surface.replace(/\s/g,'').length > 0) && (subtitle && (startIndex > 0 || phrase.surface.trim().length !== 0)))) {
                if (subtitle && buildUpSubtitle.length === 0) {
                    if (cleanSurface.length === 0) {
                        skipPost = true;
                    } else if (!subtitle.cleanText.startsWith(cleanSurface)) {
                        if (phrases.slice(phraseIndex).some(p => subtitle.cleanText.startsWith(p.surface.replace(/\s/g,'')))) {
                            skipPost = true;
                        } else {
                            if (subtitles.slice(0, 5).some(s => s.cleanText.startsWith(phrase.surface))) {
                                while (subtitle && !subtitle.cleanText.startsWith(phrase.surface)) {
                                    subtitle = subtitles.shift();
                                }
                            } else {
                                skipPost = true;
                            }
                        }
                    }

                    if (!skipPost && subtitle) {
                        newText += `<cue data-url='/api/media/external/audio/${subtitle.externalFile.id}'><i class="bi bi-play-circle"></i></cue>`;
                    }
                }
                if (phrase.isBasic) {
                    newText += `<phrase data-phrase-index='${phraseIndex}'><visual>${phrase.pronunciation}</visual><component data-component-index='0'>${phrase.surface}</component></phrase>`;
                } else {
                    newText += `<phrase data-phrase-index='${phraseIndex}'><visual>${helpers.outputAccent(phrase.pronunciation, phrase.pitchAccent.mora)}</visual>${phrase.components.map((c, i) => {
                            return `<component data-component-index='${i}' data-original='${c.original}' data-surface='${c.surface}' data-frequency-surface='${c.frequencySurface || ''}' class='underline underline-pitch-${c.pitchAccents[0].descriptive} underline-${c.frequency} status-${c.status}'>${c.ruby}</component>`;
                    }).join('')}</phrase>`;
                }

                if (!skipPost && subtitle) {
                    buildUpSubtitle += cleanSurface;

                    if (buildUpSubtitle.replace(/\s/g,'') === subtitle.cleanText) {
                        subtitle = subtitles.shift();
                        buildUpSubtitle = '';
                    }
                }
            }

            phraseIndex += 1;
            if (phraseIndex >= phrases.length) {
                phrases = sentences.shift() || [];
                phraseIndex = 0;
            }
            phrase = phrases[phraseIndex];
            if (phrase) {
                index = text.indexOf(phrase.surface.charAt(0), startIndex);
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
    } while ((didRemoveNode || walker.nextNode()) && sentences.length !== 0);
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

helpers.htmlForFurigana = async (sentence) => {
    const html = `<span class='visual-type-none ruby-type-veryCommon'><span>${sentence}</span></span>`;
    return await helpers.generateVisualSentenceElement(html, helpers.textFromHTML(sentence));
};

helpers.htmlForPitch = async (sentence) => {
    const html = `<span class='visual-type-showPitchAccent'><span>${sentence}</span></span>`;
    return await helpers.generateVisualSentenceElement(html, helpers.textFromHTML(sentence));
};

helpers.parseMarkdown = (rawText) => {
    let text = rawText.trim().replace(/(^(\r\n|\n|\r)$)|(^(\r\n|\n|\r))|^\s+$/gm, '\n\n<br />\n\n');
    let regex = /\[mpitch: (.*?)\]/mi;
    let match;
    let subst;
    while ((match = regex.exec(text)) !== null) {
        const sentence = match[1];
        const html = helpers.generateManualPitchElement(sentence);
        text = text.substring(0, match.index) + html + text.substring(match.index + match[0].length);
    }

    regex = /\[mfurigana: (.*(\[(.*?)\])*)\]/mi;
    while ((match = regex.exec(text)) !== null) {
        const s = match[1];
        const html = s.split(' ').map(x => x.replace(/(.+?)\[(.+?)\]/gmi, '<ruby>$1<rt>$2</rt></ruby>')).join('');
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
    subst = `<audio controls><source src="/api/media/audio/$1" type="audio/x-m4a"></audio>`;
    text = text.replace(regex, subst);
    // This fixes cases were HTML is right next to markdown so can't be parsed correctly.
    text = text.replace(/\n/g, '\n\n');
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

    // Anki backards compatability
    let regex = /{{furigana:\s*(.*?)}}/gmi;
    let subst = `[mfurigana: {{$1}}]`;
    result = result.replace(regex, subst);
    const modifiedFieldValues = [...fieldValues];
    modifiedFieldValues.push({ field: { name: 'Tags' }, value: '' });

    // Replace fields.
    for (let fieldValue of fieldValues) {
        const fieldName = fieldValue.field.name;
        const value = fieldValue.value;
        const replace = `{{${fieldName}}}`;
        result = result.replace(new RegExp(replace, 'g'), value.trim());

        if (!value || value.length === 0) {
            result = result.replace(new RegExp(`\{\{#${fieldName}\}\}(.*)\{\{\/${fieldName}\}\}`, 'gi'), '');
        }
    }

    regex = /{{#(.*?)}}/gmi;
    subst = ``;
    result = result.replace(regex, subst);

    regex = /{{\/(.*?)}}/gmi;
    subst = ``;
    result = result.replace(regex, subst);

    // Handle media for front / back.
    regex = /\[audio: ([A-Za-z0-9-]+)\]/gmi;
    subst = `<audio controls${autoPlay ? ' autoplay' : ''}><source src="/api/media/audio/$1" type="audio/x-m4a"></audio>`;
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

    regex = /\[furigana: (.*?)\]/mi;
    while ((match = regex.exec(result)) !== null) {
        const sentence = match[1];
        const element = await helpers.htmlForFurigana(sentence);
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
            html = `<span class="input-group"><span type='text' class='form-control d-flex justify-content-center align-items-center' disabled readonly>${value}</span><span class="input-group-text">${correct ? `<i class='bi bi-check fs-3 text-success'></i>` : `<i class='bi bi-x fs-3 text-danger'></i>`}</span></span>`;
        }
        result = result.substring(0, match.index) + html + result.substring(match.index + match[0].length);
    }

    result = helpers.parseMarkdown(result);

    if (clozeDeletionIndex && clozeDeletionIndex > 0) {
        if (showClozeDeletion) {
            result = result.replace(new RegExp(`\{\{c${clozeDeletionIndex}::([^\}]*?)(::([^\}]*?))?\}\}`, 'g'), `<span class='cloze-deletion'>$1</span>`);
        } else {
            result = result.replace(new RegExp(`\{\{c${clozeDeletionIndex}::([^\}]*?)::([^\}]*?)\}\}`, 'g'), `<span class='cloze-deletion'>[$2]</span>`);
            result = result.replace(new RegExp(`\{\{c${clozeDeletionIndex}::([^\}]*?)\}\}`, 'g'), `<span class='cloze-deletion'>[...]</span>`);
        }
    }
    result = result.replace(new RegExp(`\{\{c\\d::(.*?)(::.*?)?\}\}`, 'g'), '$1');
    return result;
};

helpers.scrollToHash = () => {
    const id = window.location.hash.substr(1);
    if (!id) { return; }
    const anchor = document.getElementById(id);
    if (!anchor) { return; }
    anchor.scrollIntoView();
};

export default helpers;
