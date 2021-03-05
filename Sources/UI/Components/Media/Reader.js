import React from 'react';
import { Readability } from '@mozilla/readability';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import ButtonGroup from 'react-bootstrap/ButtonGroup';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';
import ToggleButton from 'react-bootstrap/ToggleButton';
import Spinner from 'react-bootstrap/Spinner';
import YouTube from 'react-youtube';

import CreateNoteForm from './../Flashcard/Modals/CreateNoteForm';
import Helpers from './../Helpers';
import UserContext from './../Context/User';

class Reader extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isLoading: false,
            article: null,
            html: null,
            visualType: 'showFrequency',
            rubyType: 'none'
        };
        this.currentRequestID = 0;
    }

    componentWillMount() {
        // FIXME: For some reason this breaks in other browsers...
        if (navigator.appVersion.indexOf('Chrome/') != -1) {
            document.body.classList.add('fit-content');
        }
    }
    componentWillUnmount() {
        document.body.classList.remove('fit-content');
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
        const self = this;
        const articleContent = await Helpers.generateVisualSentenceElement(article.content, article.textContent, () => {
            return requestID != self.currentRequestID;
        });
        this.setState({ isLoading: false, html: articleContent.innerHTML });
    }

    async loadText(text) {
        if (text.length === 0) {
            this.setState({ isLoading: false });
            return;
        }
        const requestID = this.currentRequestID + 1;
        this.currentRequestID = requestID;
        const self = this;
        const articleContent = await Helpers.generateVisualSentenceElement(`<div class='page'><span>${text}</span></div>`, text, () => {
            return requestID != self.currentRequestID;
        });
        this.setState({ isLoading: false, html: articleContent ? articleContent.innerHTML : null });
    }

    frequencyOptions() {
        return [
            { name: 'Very Common', value: 'veryCommon' },
            { name: 'Common', value: 'common' },
            { name: 'Uncommon', value: 'uncommon' },
            { name: 'Rare', value: 'rare' },
            { name: 'Very Rare', value: 'veryRare' },
            { name: 'Unknown', value: 'unknown' }
        ];
    }

    furiganaFrequencyOptions() {
        return [{ name: 'Hide Furigana', value: 'none' }, ...this.frequencyOptions()];
    }

    render() {
        return (
            <UserContext.Consumer>{user => (
                <Row className='h-100'>
                    <Col className='h-100 d-flex flex-column' xs={12} md={user.settings.reader.showCreateNoteForm ? 7 : 12}>
                        <div>
                            <Form.Control autoComplete='off' className='text-center' type="text" name="youtubeID" onChange={(e) => this.load(e)} placeholder="Text / Article URL" />
                            <InputGroup className="mt-3">
                                <Form.Control value={this.furiganaFrequencyOptions().filter(f => f.value === this.state.rubyType)[0].name} readOnly />
                                <DropdownButton variant="outline-secondary" title="Furigana Minimum Frequency" id="readerRubyType">
                                    {this.furiganaFrequencyOptions().map((item, i) => {
                                        return <Dropdown.Item key={i} active={this.state.rubyType === item.value} onSelect={(e) => this.setState({ rubyType: item.value })}>{item.name}</Dropdown.Item>;
                                    })}
                                </DropdownButton>
                            </InputGroup>
                            <ButtonGroup className='my-3 d-flex' toggle>
                                {[{ name: 'Underline Frequency', value: 'showFrequency' }, { name: 'Underline Pitch Accent', value: 'showPitchAccent' }, { name: 'Show Pitch Drops', value: 'showPitchAccentDrops' }, { name: 'None', value: 'none' }].map((item, i) => (
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
                                {this.frequencyOptions().map(item => (
                                    <span className='d-inline-flex me-2'><Badge className={`bg-${item.value} me-2`}>{' '}</Badge> <span className='align-self-center'>{item.name}</span></span>
                                ))}
                            </>}

                            {this.state.visualType === 'showPitchAccent' && <>
                                {[
                                    { name: 'Heiban (平板)', value: 'heiban' },
                                    { name: 'Kihuku (起伏)', value: 'kihuku' },
                                    { name: 'Odaka (尾高)', value: 'odaka' },
                                    { name: 'Nakadaka (中高)', value: 'nakadaka' },
                                    { name: 'Atamadaka (頭高)', value: 'atamadaka' },
                                    { name: 'Unknown (知らんw)', value: 'unknown' }
                                ].map(item => (
                                    <span className='d-inline-flex me-2'><Badge className={`bg-${item.value} me-2`}>{' '}</Badge> <span className='align-self-center'>{item.name}</span></span>
                                ))}
                                <br />
                                <small>The labeled pitch accent is usually correct for each word when produced in isolation. Compound words may appear separated and with their individual accents.</small>
                            </>}
                        </div>
                        <hr />
                        {this.state.html && <div className={`px-3 overflow-auto visual-type-${this.state.visualType} ruby-type-${this.state.rubyType}`} dangerouslySetInnerHTML={{__html: this.state.html }}></div>}
                        {this.state.isLoading && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}
                    </Col>

                    {user.settings.reader.showCreateNoteForm && <Col xs={12} md={5}>
                        <CreateNoteForm className='mt-3 mt-md-0' onSuccess={() => { }} />
                    </Col>}
                </Row>
            )
        }</UserContext.Consumer>);
    }
}

export default Reader;
