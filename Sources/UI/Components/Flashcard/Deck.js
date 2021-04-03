import { withRouter } from 'react-router';
import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';
import UserContext from './../Context/User';

import AceEditor from 'react-ace';
import 'ace-builds/webpack-resolver';
import 'ace-builds/src-noconflict/mode-css';
import 'ace-builds/src-noconflict/mode-html';
import 'ace-builds/src-noconflict/theme-github';
import 'ace-builds/src-noconflict/ext-language_tools';
ace.config.set('basePath', '/generated');

import _ from 'underscore';
import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import ButtonGroup from 'react-bootstrap/ButtonGroup';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import Tab from 'react-bootstrap/Tab';
import Tabs from 'react-bootstrap/Tabs';
import Table from 'react-bootstrap/Table';

import scoper from './scoper.js';
import Helpers from './../Helpers';
import KeybindObserver from './../KeybindObserver';

class Deck extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            cardType: null,
            loadedHTML: null,
            showGradeButtons: false,
            answers: {}
        };

        this.onKeybind = this.onKeybind.bind(this);
    }

    componentDidMount() {
        this.load();
        Helpers.addLiveEventListeners('.card-field-answer', 'input', (e, target) => {
            const digest = target.dataset.key;
            this.state.answers[digest] = target.value;
        });
    }

    async load() {
        const id = this.props.match.params.id;
        const response = await fetch(id ? `/api/flashcard/deck/${id}/nextCard` : `/api/flashcard/decks/nextCard`);
        if (response.ok) {
            const nextCard = await response.json();
            this.setState({ nextCard, loadedHTML: null, showGradeButtons: false });
            await this.loadFront();
        } else {
            return this.props.history.push('/flashcard/decks');
        }
    }

    async loadFront() {
        await this.loadHTML(this.state.nextCard.cardType.frontHTML, this.state.nextCard.cardType.css, 'front');
    }

    async loadBack() {
        await this.loadHTML(this.state.nextCard.cardType.backHTML, this.state.nextCard.cardType.css, 'back');
    }

    async loadHTML(html, css, id) {
        let result = await Helpers.htmlForCard(html, {
            fieldValues: this.state.nextCard.note.fieldValues,
            autoPlay: true,
            answers: this.state.answers,
            answersType: id !== 'front' ? 'show' : 'none',
            showClozeDeletion: id !== 'front',
            clozeDeletionIndex: this.state.nextCard.clozeDeletionIndex
        });

        if (id !== 'front') {
            const frontSide = await Helpers.htmlForCard(this.state.nextCard.cardType.frontHTML, {
                fieldValues: this.state.nextCard.note.fieldValues,
                autoPlay: false,
                answers: this.state.answers,
                answersType: 'echo',
                showClozeDeletion: true,
                clozeDeletionIndex: this.state.nextCard.clozeDeletionIndex
            });
            result = result.replace(/{{FrontSide}}/g, frontSide);
        }

        result = `<div id="${`card_${id}`}">
            <style>
                ${scoper(css, `#card_${id}`)}
            </style>

            <div id="card">
                <div id="${id}">


                ${result}

                </div>
            </div>
        </div>`;

        this.setState({ loadedHTML: result });
    }

    async showAnswer() {
        await this.loadBack();
        this.setState({ showGradeButtons: true });
    }

    async selectGrade(grade) {
        this.setState({ showGradeButtons: false, loadedHTML: null });
        await fetch(`/api/flashcard/card/${this.state.nextCard.id}/grade/${grade}`, {
            method: 'POST'
        });
        document.body.dispatchEvent(new Event('ankiChange', { bubbles: true }));
        await this.load();
    }

    onKeybind(matchesKeybind) {
        if (!this.state.nextCard || !this.state.loadedHTML) {
            return;
        }

        if (!this.state.showGradeButtons && matchesKeybind(this.context.settings.anki.keybinds.showAnswer)) {
            this.showAnswer();
        } else if (this.state.showGradeButtons) {
            if (matchesKeybind(this.context.settings.anki.keybinds.grade0)) {
                this.selectGrade(0);
            } else if (matchesKeybind(this.context.settings.anki.keybinds.grade1)) {
                this.selectGrade(1);
            } else if (matchesKeybind(this.context.settings.anki.keybinds.grade2)) {
                this.selectGrade(2);
            } else if (matchesKeybind(this.context.settings.anki.keybinds.grade3)) {
                this.selectGrade(3);
            } else if (matchesKeybind(this.context.settings.anki.keybinds.grade4)) {
                this.selectGrade(4);
            } else if (matchesKeybind(this.context.settings.anki.keybinds.grade5)) {
                this.selectGrade(5);
            }
        }
    }

    render() {
        return (
            <KeybindObserver onKeybind={this.onKeybind}>
                <div>
                    {(!this.state.nextCard || !this.state.loadedHTML) && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}

                    {this.state.nextCard && this.state.loadedHTML && <div>
                        <Row>
                            <Col xs={0} lg={3}></Col>
                            <Col xs={12} lg={6}>
                                <div dangerouslySetInnerHTML={{ __html: this.state.loadedHTML }}></div>
                                {!this.state.showGradeButtons && <div className="d-grid">
                                    <Button block variant="primary" className="mt-3" onClick={() => this.showAnswer()}>Show Answer</Button>
                                </div>}
                                {this.state.showGradeButtons && <div className="text-center mt-3">
                                    <span className='px-2'>Fail</span>
                                    <ButtonGroup className="mb-2　d-block">
                                        <Button variant='danger' onClick={() => this.selectGrade(1)}>1</Button>
                                        <Button variant='danger' onClick={() => this.selectGrade(2)}>2</Button>
                                        <Button variant='success' onClick={() => this.selectGrade(3)}>3</Button>
                                        <Button variant='success' onClick={() => this.selectGrade(4)}>4</Button>
                                        <Button variant='success' onClick={() => this.selectGrade(5)}>5</Button>
                                    </ButtonGroup>
                                    <span className='px-2'>Pass</span>
                                </div>}
                            </Col>
                            <Col xs={0} lg={3}></Col>
                        </Row>
                    </div>}
                </div>
            </KeybindObserver>
        );
    }
}

Deck.contextType = UserContext;
export default withRouter(Deck);
