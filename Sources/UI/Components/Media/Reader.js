import React from 'react';
import { Readability } from '@mozilla/readability';
import { LinkContainer } from 'react-router-bootstrap';
import { gzip } from 'pako';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import ButtonGroup from 'react-bootstrap/ButtonGroup';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';
import ToggleButton from 'react-bootstrap/ToggleButton';
import Spinner from 'react-bootstrap/Spinner';
import YouTube from 'react-youtube';

import CreateNoteForm from './../Flashcard/Modals/CreateNoteForm';

class Reader extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isLoading: false,
            article: null,
            html: null,
            visualType: 'showFrequency'
        };
        this.currentRequestID = 0;
    }

    load(e) {
        const text = e.target.value;
        this.setState({ article: null, isLoading: true, html: null });
        if (/(https?:\/\/[^\s]+)/.test(text)) {
            const url = text;
            this.loadURL(url);
        } else {
            this.loadText(text);
        }
    }

    async loadURL(url) {
        const requestID = this.currentRequestID + 1;
        this.currentRequestID = requestID;
        const response = await fetch(`/api/proxy?url=${encodeURIComponent(url)}`);
        const html = await response.text();
        const doc = document.implementation.createHTMLDocument(url);
        doc.documentElement.innerHTML = html
            .replace('<title>', `<base href="${new URL(url).origin}">\n<title>`);
        doc.documentElement.querySelectorAll('rp').forEach(item => {
            item.parentNode.removeChild(item);
        });
        doc.documentElement.querySelectorAll('rt').forEach(item => {
            item.parentNode.removeChild(item);
        });
        doc.documentElement.innerHTML = doc.documentElement.innerHTML
            .replace(/<ruby>/g, '')
            .replace(/<\/ruby>/g, '')
            .replace(/<rb>/g, '')
            .replace(/<\/rb>/g, '')
            .replace(/<rt>/g, '')
            .replace(/<\/rt>/g, '')
            .replace(/<rp>/g, '')
            .replace(/<\/rp>/g, '');
        const article = new Readability(doc).parse();

        const sentenceResponse = await fetch(`/api/lists/sentence/parse`, {
            method: 'POST',
            body: await gzip(article.textContent),
            headers: {
                'Content-Encoding': 'gzip'
            }
        });
        let nodes = await sentenceResponse.json();
        nodes = nodes.filter(n => n.shouldDisplay);
        if (requestID != this.currentRequestID) return;

        const articleContent = document.createElement('div');
        articleContent.innerHTML = article.content;
        this.loadElement(articleContent, nodes);
        if (requestID != this.currentRequestID) return;
        this.setState({ isLoading: false, article, html: articleContent.innerHTML });
    }

    async loadText(text) {
        if (text.length == 0) {
            this.setState({ isLoading: false });
            return;
        }
        const requestID = this.currentRequestID + 1;
        this.currentRequestID = requestID;
        const sentenceResponse = await fetch(`/api/lists/sentence/parse`, {
            method: 'POST',
            body: await gzip(text),
            headers: {
                'Content-Encoding': 'gzip'
            }
        });
        let nodes = await sentenceResponse.json();
        nodes = nodes.filter(n => n.shouldDisplay);
        if (requestID != this.currentRequestID) return;

        const articleContent = document.createElement('div');
        articleContent.innerHTML = `<div class='page'><span>${text}</span></div>`;
        this.loadElement(articleContent, nodes);
        if (requestID != this.currentRequestID) return;
        this.setState({ isLoading: false, html: articleContent.innerHTML });
    }

    loadElement(contentElement, nodes) {
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
                    newText += `<span class='underline underline-pitch-${node.pitchAccent} underline-${node.frequency}'>${node.surface}</span>`;
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
    }

    render() {
        return (
            <Row>
                <Col xs={12} md={7}>
                    <Form.Control autoComplete='off' className='text-center' type="text" name="youtubeID" onChange={(e) => this.load(e)} placeholder="Text / Article URL" />
                    <ButtonGroup className='my-3 d-flex' toggle>
                        {[{ name: 'Show Frequency', value: 'showFrequency' }, { name: 'Show Pitch Accent', value: 'showPitchAccent' }, { name: 'None', value: 'none' }].map((item, i) => (
                            <ToggleButton
                                id={`visualType${item.value}`}
                                key={i}
                                type="radio"
                                variant="secondary"
                                name="visualType"
                                value={item.value}
                                checked={this.state.visualType === item.value}
                                onChange={(e) => this.setState({ visualType: e.target.value })}>
                            {item.name}
                            </ToggleButton>
                        ))}
                    </ButtonGroup>
                    {this.state.visualType === 'showFrequency' && <>
                        {[
                            { name: 'Very Common', value: 'veryCommon' },
                            { name: 'Common', value: 'common' },
                            { name: 'Uncommon', value: 'uncommon' },
                            { name: 'Rare', value: 'rare' },
                            { name: 'Very Rare', value: 'veryRare' },
                            { name: 'Unknown', value: 'unknown' }
                        ].map(item => (
                            <span className='d-inline-flex me-2'><Badge className={`bg-${item.value} me-2`}>{' '}</Badge> <span className='align-self-center'>{item.name}</span></span>
                        ))}
                    </>}

                    {this.state.visualType === 'showPitchAccent' && <>
                        {[
                            { name: 'Heiban (平板)', value: 'heiban' },
                            { name: 'Kihuku (起伏)', value: 'kihuku' },
                            { name: 'Odaka (尾高)', value: 'odaka' },
                            { name: 'Nakadaka (中高)', value: 'nakadaka' },
                            { name: 'Atamadak (頭高)', value: 'atamadaka' },
                            { name: 'Unknown (知らんw)', value: 'unknown' }
                        ].map(item => (
                            <span className='d-inline-flex me-2'><Badge className={`bg-${item.value} me-2`}>{' '}</Badge> <span className='align-self-center'>{item.name}</span></span>
                        ))}
                    </>}
                    <hr />
                    {this.state.html && <div className={`p-3 visual-type-${this.state.visualType}`} dangerouslySetInnerHTML={{__html: this.state.html }}></div>}
                    {this.state.isLoading && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}
                </Col>

                <Col xs={12} md={5}>
                    <CreateNoteForm className='mt-3 mt-md-0' onSuccess={() => { }} />
                </Col>
            </Row>
        );
    }
}

export default Reader;
