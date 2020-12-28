import { withRouter } from "react-router";
import React from "react";
import { LinkContainer } from 'react-router-bootstrap';

import AceEditor from "react-ace";
import "ace-builds/webpack-resolver";
import "ace-builds/src-noconflict/mode-css";
import "ace-builds/src-noconflict/mode-html";
import "ace-builds/src-noconflict/theme-github";
import "ace-builds/src-noconflict/ext-language_tools";

ace.config.set("basePath", "/generated");

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

class Deck extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            deck: null,
            cardType: null,
            loadedHTML: null,
            showGradeButtons: false
        };
    }

    componentDidMount() {
        this.load();
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
        const availableQueue = this.state.deck.sm.queue.filter(i => new Date(i.dueDate) < new Date());
        const item = availableQueue[0];
        if (!item) {
            this.props.history.push("/flashcard/decks");
            return;
        }
        const response = await fetch(`/api/flashcard/card/${item.card}`);
        if (response.ok) {
            const nextCard = await response.json();
            this.setState({ nextCard, loadedHTML: null, showGradeButtons: false });
            this.loadFront();
        }
    }

    loadFront() {
        this.loadHTML(this.state.nextCard.cardType.frontHTML, this.state.nextCard.cardType.css, "front");
    }

    loadBack() {
        this.loadHTML(this.state.nextCard.cardType.backHTML, this.state.nextCard.cardType.css, "back");
    }

    loadHTML(html, css, id) {
        let result = `
        <div id="${`card_${id}`}">
            <style>
                ${scoper(css, `#card_${id}`)}
            </style>

            <div id="card">
                <div id="${id}">
                    ${html}
                </div>
            </div>
        </div>
        `;

        if (id !== "front") {
            result = result.replace(/{{FrontSide}}/g, this.state.nextCard.cardType.frontHTML);
        }

        for (let fieldValue of this.state.nextCard.note.fieldValues) {
            const fieldName = fieldValue.field.name;
            const value = fieldValue.value;
            const replace = `{{${fieldName}}}`;
            result = result.replace(new RegExp(replace, 'g'), value);
        }

        this.setState({ loadedHTML: result });
    }

    showAnswer() {
        this.loadBack();
        this.setState({ showGradeButtons: true });
    }

    async selectGrade(grade) {
        this.setState({ showGradeButtons: false, loadedHTML: null });
        await fetch(`/api/flashcard/card/${this.state.nextCard.id}/grade/${grade}`, {
            method: "POST"
        });
        await this.load();
    }

    render() {
        return (
            <div>
                {(!this.state.nextCard || !this.state.loadedHTML) && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}

                {this.state.nextCard && this.state.loadedHTML&& <div>
                    <Row>
                        <Col xs={3}></Col>
                        <Col xs={6}>
                            <div dangerouslySetInnerHTML={{ __html: this.state.loadedHTML }}></div>
                            <hr />
                            {!this.state.showGradeButtons && <Button block variant="primary" className="mt-3" onClick={() => this.showAnswer()}>Show Answer</Button>}
                            {this.state.showGradeButtons && <ButtonGroup style={{ display: 'block', 'text-align': 'center' }} className="mb-2　d-block">
                                <Button onClick={() => this.selectGrade(1)}>Again</Button>
                                <Button onClick={() => this.selectGrade(3)}>Good</Button>
                                <Button onClick={() => this.selectGrade(5)}>Easy</Button>
                            </ButtonGroup>}
                        </Col>
                        <Col xs={3}></Col>
                    </Row>
                </div>}
            </div>
        )
    }
}

export default withRouter(Deck);
