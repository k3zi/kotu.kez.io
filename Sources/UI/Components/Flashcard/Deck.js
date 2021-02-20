import { withRouter } from 'react-router';
import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

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

class Deck extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            deck: null,
            cardType: null,
            loadedHTML: null,
            showGradeButtons: false,
            answers: {}
        };
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
        const response = await fetch(`/api/flashcard/deck/${id}`);
        if (response.ok) {
            const deck = await response.json();
            this.setState({ deck });
            await this.loadNextCard();
        }
    }

    async loadNextCard() {
        const allItems = this.state.deck.sm.queue.filter(i => new Date(i.dueDate) < new Date());
        const newItems = allItems.filter(i => i.repetition === -1);
        const reviewItems = allItems.filter(i => i.repetition !== -1);

        let items = allItems;
        let shouldRandomize = false;
        const scheduleOrder = this.state.deck.scheduleOrder;
        const newOrder = this.state.deck.newOrder;
        const reviewOrder = this.state.deck.reviewOrder;
        if (scheduleOrder === 'newAfterReview') {
            if (reviewItems.length > 0) {
                items = reviewItems;
                if (reviewOrder === 'random') {
                    items = _.shuffle(items);
                }
            } else if (newOrder === 'random') {
                // all new cards
                items = _.shuffle(items);
            }
        } else if (scheduleOrder === 'newBeforeReview' && newItems.length > 0) {
            if (newItems.length > 0) {
                items = newItems;
                if (newOrder === 'random') {
                    items = _.shuffle(items);
                }
            } else if (reviewOrder === 'random') {
                // all review cards
                items = _.shuffle(items);
            }
        } else if (reviewOrder == 'random' && newOrder == 'random') {
            items = _.shuffle(items);
        }

        const item = items[0];
        if (!item) {
            this.props.history.push('/flashcard/decks');
            return;
        }
        const response = await fetch(`/api/flashcard/card/${item.card}`);
        if (response.ok) {
            const nextCard = await response.json();
            this.setState({ nextCard, loadedHTML: null, showGradeButtons: false });
            await this.loadFront();
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
        await this.load();
    }

    render() {
        return (
            <div>
                {(!this.state.nextCard || !this.state.loadedHTML) && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}

                {this.state.nextCard && this.state.loadedHTML&& <div>
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
        );
    }
}

export default withRouter(Deck);
