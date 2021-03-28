import _ from 'underscore';
import React from 'react';
import { withRouter } from 'react-router';
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
            session: null,
            text: '',
            didInitialScroll: false,
            isScrolling: false
        };
        this.currentRequestID = 0;
        const self = this;
        this.throttledUpdateSession = _.throttle(() => {
            self.updateSession();
        }, 500);
    }

    componentWillMount() {
        // FIXME: For some reason fit-content breaks in other browsers...
        if (navigator.appVersion.indexOf('Chrome/') != -1) {
            document.body.classList.add('fit-content');
        }

        if (this.state.session && (!this.props.match.params.id || this.props.match.params.id.length === 0)) {
            this.setState({ session: null });
        } else if (!this.state.session || this.state.session.id != this.props.match.params.id) {
            this.loadSession(this.props.match.params.id);
        }
    }

    componentWillUnmount() {
        document.body.classList.remove('fit-content');
    }

    componentDidUpdate(prevProps) {
        if (this.state.session && (!this.props.match.params.id || this.props.match.params.id.length === 0)) {
            this.setState({ session: null });
        } else if (!this.state.session || this.state.session.id != this.props.match.params.id) {
            this.loadSession(this.props.match.params.id);
        }

        if (!this.state.didInitialScroll && this.state.session && !this.state.isScrolling) {
            this.setState({ isScrolling: true });
            if (this.state.session.scrollPhraseIndex && this.state.session.scrollPhraseIndex > 0) {
                const phrase = document.querySelector(`[data-phrase-index='${this.state.session.scrollPhraseIndex}']`);
                if (phrase) {
                    phrase.scrollIntoView({ behavior: 'smooth' });
                }
            }
            this.setState({ didInitialScroll: true });

            const self = this;
            setTimeout(() => {
                self.setState({ isScrolling: false });
            }, 3000);
        }
    }

    load(e) {
        const text = e.target.value;
        this.setState({ article: null, isLoading: true, html: null, text });
        if (/(https?:\/\/[^\s]+)/.test(text)) {
            const url = text;
            this.loadURL(url);
        } else {
            this.loadText(text);
        }
    }

    async loadSession(id) {
        if (this.loadingSessionID === id) {
            return;
        }
        this.loadingSessionID = id;
        if (!id) { return; }
        let sessionResponse = await fetch(`/api/media/reader/session/${id}`);
        let session = sessionResponse.ok ? (await sessionResponse.json()) : null;
        if (session) {
            this.setState({ isLoading: true, html: session.annotatedContent, session, text: session.url || session.textContent });

            const requestID = this.currentRequestID + 1;
            this.currentRequestID = requestID;
            const annotatedContent = await Helpers.generateVisualSentenceElement(session.content, session.textContent, () => {
                return requestID != this.currentRequestID;
            });

            if (annotatedContent) {
                const session = this.state.session;
                if (!session) { return; }
                session.annotatedContent = annotatedContent.innerHTML;
                this.setState({ isLoading: false, html: annotatedContent.innerHTML, session });
                this.updateSession();
            }
        } else {
            this.props.history.push(`/media/reader`);
        }
    }

    async loadURL(url) {
        let sessionResponse = await fetch(`/api/media/reader/session/url/${encodeURIComponent(url)}`);
        let session = sessionResponse.ok ? (await sessionResponse.json()) : null;
        if (session) {
            this.setState({ isLoading: false, html: session.annotatedContent, session });
            this.props.history.push(`/media/reader/${session.id}`);
            return;
        }
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

        const sessionData = {
            annotatedContent: "",
            textContent: article.textContent,
            content: article.content,
            url: url,
            visualType: 'showFrequency',
            rubyType: 'none',
            title: article.title
        };
        sessionResponse = await fetch('/api/media/reader/session', {
            method: 'POST',
            body: JSON.stringify(sessionData),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        session = sessionResponse.ok ? (await sessionResponse.json()) : null;
        if (session) {
            this.setState({ isLoading: false, html: session.annotatedContent, session });
            this.props.history.push(`/media/reader/${session.id}`);
        } else {
            this.setState({ isLoading: false, html: '', session: null });
            this.props.history.push(`/media/reader`);
        }
    }

    async loadText(text) {
        let session = this.state.session;
        if (session && session.url) {
            session = null;
        }
        const requestID = this.currentRequestID + 1;
        this.currentRequestID = requestID;
        const self = this;
        const textContent = text;
        const content = `<div class='page'><span>${text}</span></div>`;
        const annotatedContentNode = await Helpers.generateVisualSentenceElement(content, textContent, () => {
            return requestID != self.currentRequestID;
        });
        if (!annotatedContentNode) {
            return;
        }
        const annotatedContent = annotatedContentNode.innerHTML;

        if (session) {
            // Update
            session.annotatedContent = annotatedContent;
            session.textContent = textContent;
            session.content = content;
            const sessionResponse = await fetch(`/api/media/reader/session/${session.id}`, {
                method: 'PUT',
                body: JSON.stringify(session),
                headers: {
                    'Content-Type': 'application/json'
                }
            });
            session = sessionResponse.ok ? (await sessionResponse.json()) : null;
        } else {
            // Create New
            const sessionData = {
                annotatedContent: annotatedContent,
                textContent: textContent,
                content: content,
                url: null,
                visualType: 'showFrequency',
                rubyType: 'none'
            };
            const sessionResponse = await fetch('/api/media/reader/session', {
                method: 'POST',
                body: JSON.stringify(sessionData),
                headers: {
                    'Content-Type': 'application/json'
                }
            });
            session = sessionResponse.ok ? (await sessionResponse.json()) : null;
        }
        this.setState({ isLoading: false, html: annotatedContent, session });
        if (session) {
            this.props.history.push(`/media/reader/${session.id}`);
        } else {
            this.props.history.push(`/media/reader`);
        }
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

    setRubyType(item) {
        const session = this.state.session;
        if (!session) { return; }
        session.rubyType = item.value;
        this.setState({ session });
        this.updateSession();
    }

    setVisualType(item) {
        const session = this.state.session;
        if (!session) { return; }
        session.visualType = item.value;
        this.setState({ session });
        this.updateSession();
    }

    async updateSession() {
        const session = this.state.session;
        if (!session) { return; }
        await fetch(`/api/media/reader/session/${session.id}`, {
            method: 'PUT',
            body: JSON.stringify({
                visualType: session.visualType,
                rubyType: session.rubyType,
                scrollPhraseIndex: session.scrollPhraseIndex || 0
            }),
            headers: {
                'Content-Type': 'application/json'
            }
        });
    }

    onScroll(element) {
        if (!element || !this.state.didInitialScroll || this.state.isScrolling) return;
        const elementTop = element.offsetTop;
        const phrases = [...element.querySelectorAll('phrase')];
        let phrase = null;
        let minOffset = 0;
        phrases.forEach(p => {
            let offset = Math.abs(element.scrollTop - (p.offsetTop - elementTop));
            if (!phrase || offset < minOffset) {
                minOffset = offset;
                phrase = p;
            }
        });
        if (phrase) {
             this.state.session.scrollPhraseIndex = parseInt(phrase.dataset.phraseIndex) || 0;
             this.throttledUpdateSession();
        }
    }

    render() {
        return (
            <UserContext.Consumer>{user => (
                <Row className='h-100'>
                    <Col className='h-100 d-flex flex-column' xs={12} md={user.settings.reader.showCreateNoteForm ? 7 : 12}>
                        <div>
                            <Form.Control autoComplete='off' className='text-center' type="text" onChange={(e) => this.load(e)} placeholder="Text / Article URL" value={this.state.text} />
                            {this.state.session && <>
                                <InputGroup className="mt-3">
                                    <Form.Control value={this.furiganaFrequencyOptions().filter(f => f.value === this.state.session.rubyType)[0].name} readOnly />
                                    <DropdownButton variant="outline-secondary" title="Furigana Minimum Frequency" id="readerRubyType">
                                        {this.furiganaFrequencyOptions().map((item, i) => {
                                            return <Dropdown.Item key={i} active={this.state.session.rubyType === item.value} onSelect={(e) => this.setRubyType(item)}>{item.name}</Dropdown.Item>;
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
                                            checked={this.state.session.visualType === item.value}
                                            onChange={(e) => this.setVisualType(item)}>
                                            {item.name}
                                        </ToggleButton>
                                    ))}
                                </ButtonGroup>
                                {this.state.session.visualType === 'showFrequency' && <>
                                    {this.frequencyOptions().map(item => (
                                        <span className='d-inline-flex me-2'><Badge className={`bg-${item.value} me-2`}>{' '}</Badge> <span className='align-self-center'>{item.name}</span></span>
                                    ))}
                                </>}

                                {this.state.session.visualType === 'showPitchAccent' && <>
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
                            </>}
                        </div>
                        <hr />
                        {this.state.html && this.state.session && <div className={`px-3 overflow-auto visual-type-${this.state.session.visualType} ruby-type-${this.state.session.rubyType}`} onScroll={(e) => this.onScroll(e.target)} ref={(r) => this.onScroll(r)} dangerouslySetInnerHTML={{__html: this.state.html }}></div>}
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

export default withRouter(Reader);
