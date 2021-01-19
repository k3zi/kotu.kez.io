import { gzip } from 'pako';

const helpers = {};

helpers.generateVisualSentenceElement = async function(content, textContent, isCancelled) {
    const sentenceResponse = await fetch(`/api/lists/sentence/parse`, {
        method: 'POST',
        body: await gzip(textContent),
        headers: {
            'Content-Encoding': 'gzip'
        }
    });
    let nodes = await sentenceResponse.json();
    nodes = nodes.filter(n => n.shouldDisplay);
    if (isCancelled && isCancelled()) {
        return;
    }

    const contentElement = document.createElement('div');
    contentElement.innerHTML = content;

    const walker = document.createTreeWalker(contentElement, NodeFilter.SHOW_TEXT);
    let nodeIndex = 0;
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
        let node = nodes[nodeIndex];
        let index = text.indexOf(node.surface, startIndex);
        while (index != -1) {
            if (node.isBasic) {
                newText += `<span>${node.surface}</span>`;
            } else {
                newText += `<word data-headwords='${JSON.stringify(node.headwords)}' class='underline underline-pitch-${node.pitchAccent} underline-${node.frequency}'>${node.ruby}</word>`;
            }

            nodeIndex += 1;
            node = nodes[nodeIndex];
            if (node) {
                index = text.indexOf(node.surface, startIndex);
                startIndex += node.surface.length;
            } else {
                index = -1
            }
        }
        if (newText.length > 0) {
            const newElement = document.createElement('span');
            newElement.innerHTML = newText;
            element.before(newElement);

            // Have to go to the next node or else we lose our place.
            walker.nextNode();
            element.remove();
            didRemoveNode = true;
        }
    } while ((didRemoveNode || walker.nextNode()) && nodeIndex < nodes.length);
    return contentElement;
}

export default helpers;
