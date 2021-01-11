import React from 'react';
import { Readability } from '@mozilla/readability';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';
import Spinner from 'react-bootstrap/Spinner';
import YouTube from 'react-youtube';

import CreateNoteForm from './../Flashcard/Modals/CreateNoteForm';

class Reader extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isLoading: false,
            article: null,
            html: null
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
        const article = new Readability(doc).parse();

        const sentenceResponse = await fetch(`/api/lists/sentence/parse`, {
            method: 'POST',
            body: article.textContent
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
            body: text
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
                    newText += `<span class='underline underline-${node.frequency}'>${node.surface}</span>`;
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
                    {this.state.html && <div className='p-3' dangerouslySetInnerHTML={{__html: this.state.html }}></div>}
                    {this.state.isLoading && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}
                    <hr />
                    <h4>Key</h4>
                    <div className='d-flex mb-2'><Badge className='bg-veryCommon me-2'>{' '}</Badge> <span className='align-self-center'>Very Common</span></div>
                    <div className='d-flex mb-2'><Badge className='bg-common me-2'>{' '}</Badge> <span className='align-self-center'>Common</span></div>
                    <div className='d-flex mb-2'><Badge className='bg-uncommon me-2'>{' '}</Badge> <span className='align-self-center'>Uncommon</span></div>
                    <div className='d-flex mb-2'><Badge className='bg-rare me-2'>{' '}</Badge> <span className='align-self-center'>Rare</span></div>
                    <div className='d-flex mb-2'><Badge className='bg-veryRare me-2'>{' '}</Badge> <span className='align-self-center'>Very Rare</span></div>
                    <div className='d-flex mb-2'><Badge className='bg-unknown me-2'>{' '}</Badge> <span className='align-self-center'>Unknown</span></div>
                </Col>

                <Col xs={12} md={5}>
                    <CreateNoteForm className='mt-3 mt-md-0' onSuccess={() => { }} />
                </Col>
            </Row>
        );
    }
}

export default Reader;
