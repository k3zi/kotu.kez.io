import { withRouter } from 'react-router';
import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

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
import ListGroup from 'react-bootstrap/ListGroup';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import Tab from 'react-bootstrap/Tab';
import Tabs from 'react-bootstrap/Tabs';
import Table from 'react-bootstrap/Table';

import Helpers from './../../Helpers';

class Names extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            name: null,
            nameHTML: null,
            answerHTML: null,
            started: false,
            history: [],
            correctCount: 0,
            incorrectCount: 0
        };
    }

    componentDidMount() {
    }

    async start() {
        this.setState({ started: true });
        this.load();
    }

    async load() {
        const response = await fetch(`/api/tests/pitchAccent/names/random`);
        if (response.ok) {
            const name = await response.json();
            const text = `${name.lastName.kanji}${name.firstName.kanji}`;
            const element = await Helpers.generateVisualSentenceElement(`<span class='visual-type-none ruby-type-veryCommon page fs-2'><span>${text}</span></span>`, text);
            this.setState({ name, answerHTML: null, nameHTML: element.innerHTML });
        }
    }

    async showAnswer() {
        const text = `${this.state.name.lastName.kanji}${this.state.name.firstName.kanji}`;
        const element = await Helpers.generateVisualSentenceElement(`<div class='page'><span>${text}</span></div>`, text);
        this.setState({ answerHTML: element.innerHTML });
    }

    markCorrect() {
        this.mark(true);
    }

    markIncorrect() {
        this.mark(false);
    }

    mark(correct) {
        const history = this.state.history;
        const name = this.state.name;
        history.unshift({
            correct,
            name
        });
        this.setState({ history, correctCount: history.filter(i => i.correct).length, incorrectCount: history.filter(i => !i.correct).length })
        this.load();
    }


    accentOutput(word, accent) {
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
    }

    render() {
        return (
            <div>
                {!this.state.started && <Row>
                    <Col xs={0} lg={3}></Col>
                    <Col xs={12} lg={6}>
                        <h3 className='text-center'>Name Pitch Accent Recall Test</h3>
                        <div className="d-grid">
                            <Button block variant="primary" onClick={() => this.start()}>Start</Button>
                        </div>
                    </Col>
                    <Col xs={0} lg={3}></Col>
                </Row>}
                {!this.state.name && this.state.started && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}

                {this.state.name && <div>
                    <Row>
                        <Col xs={12} lg={3} className='order-2 order-lg-0 mt-3 mt-lg-0'>
                            <h4 className='text-center'>History</h4>
                            <ListGroup className="overflow-auto hide-scrollbar max-vh-75">
                                {this.state.history.map((item, i) => {
                                    return <ListGroup.Item key={i} variant={item.correct ? 'success' : 'danger'}>{this.accentOutput(item.name.lastNamePronunciation, item.name.lastNamePitchAccent.mora)}・{this.accentOutput(item.name.firstNamePronunciation, item.name.firstNamePitchAccent.mora)}</ListGroup.Item>;
                                })}
                            </ListGroup>
                        </Col>
                        <Col xs={12} lg={6} className='text-center order-0 order-lg-1'>
                            {this.state.nameHTML && <h2 className='text-center' dangerouslySetInnerHTML={{__html: this.state.nameHTML}}></h2>}
                            {this.state.answerHTML && <div>
                                <hr />
                                <span className={`fs-5 visual-type-showPitchAccentDrops text-center`} dangerouslySetInnerHTML={{__html: this.state.answerHTML}}></span>
                                <audio controls autoPlay>
                                    <source src={`/api/tests/pitchAccent/names/speech/${this.state.name.gender}/${this.state.name.firstNameIndex}/${this.state.name.lastNameIndex}`} type='audio/mpeg' />
                                </audio>
                            </div>}
                            {!this.state.answerHTML && <div className="d-grid">
                                <Button block variant="primary" onClick={() => this.showAnswer()}>Show Answer</Button>
                            </div>}
                            {this.state.answerHTML && <div className='d-flex justify-content-evenly mt-3'>
                                <Button className='flex-fill mx-2' block variant='danger' onClick={() => this.markIncorrect()}>Incorrect</Button>
                                <Button className='flex-fill mx-2' block variant='success' onClick={() => this.markCorrect()}>Correct</Button>
                            </div>}
                        </Col>
                        <Col xs={12} lg={3} className='order-1 order-lg-2 mt-3 mt-lg-0 d-flex align-items-center justify-content-center'>
                            <h3 className='text-center'>Correct<br/>{this.state.correctCount} of {this.state.correctCount + this.state.incorrectCount} ({this.state.history.length == 0 ? '0' : Math.round((this.state.correctCount / (this.state.correctCount + this.state.incorrectCount)) * 100)}%)</h3>
                        </Col>
                    </Row>
                </div>}
            </div>
        );
    }
}

export default Names;
