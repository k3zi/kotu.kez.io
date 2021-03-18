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
import ToggleButtonGroup from 'react-bootstrap/ToggleButtonGroup';
import ToggleButton from 'react-bootstrap/ToggleButton';

import Helpers from './../../Helpers';

import UserContext from './../../Context/User';

class Counters extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            allCounters: [],
            selectedCounters: [],
            number: null,
            numberHTML: null,
            answer: null,
            otherAnswers: [],
            started: false,
            history: [],
            correctCount: 0,
            incorrectCount: 0
        };
    }

    componentDidMount() {
        this.preload();
    }

    async start() {
        this.setState({ started: true });
        this.load();
    }

    async preload() {
        const response = await fetch(`/api/tests/pitchAccent/counters/all`);
        if (response.ok) {
            const allCounters = await response.json();
            this.setState({ allCounters, selectedCounters: allCounters });
        }
    }

    toggleCounter(id) {
        if (this.state.selectedCounters.filter(c => c.id === id).length > 0) {
            this.state.selectedCounters = this.state.selectedCounters.filter(c => c.id !== id);
        } else {
            this.state.selectedCounters.unshift(this.state.allCounters.filter(c => c.id === id)[0]);
        }
        this.setState({ selectedCounters: this.state.selectedCounters });
    }

    deselectAllCounters() {
        this.setState({ selectedCounters: [] });
    }

    selectAllCounters() {
        this.setState({ selectedCounters: this.state.allCounters });
    }

    async load() {
        const data = this.state.selectedCounters.map(c => c.id);
        const response = await fetch(`/api/tests/pitchAccent/counters/random`, {
            method: 'POST',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });

        if (response.ok) {
            const number = await response.json();
            number.counter = number.counter === '整数' ? '' : number.counter;
            const element = await Helpers.parseMarkdown(`[mfurigana: ${number.number} ${number.counter}${number.counter && number.counter.length > 0 && number.counter !== number.kana ? `[${number.kana}]` : ''}]`);
            this.setState({
                number,
                numberHTML: this.context.settings.tests.pitchAccent.showFurigana ? element : `${number.number}${number.counter}`,
                answer: null,
                otherAnswers: []
            });
        }
    }

    async showAnswer() {
        const answers = this.state.number.accents.map(accent => {
            const html = Helpers.parseMarkdown(`[mpitch: ${accent.accent.map(a => Helpers.outputAccentPlainText(a.pronunciation, a.pitchAccent)).join('・')}]`);
            const soundFile = accent.soundFile;
            return { html, soundFile };
        });
        const answer = answers.shift();
        this.setState({ answer, otherAnswers: answers });
    }

    markCorrect() {
        this.mark(true);
    }

    markIncorrect() {
        this.mark(false);
    }

    mark(correct) {
        const history = this.state.history;
        const number = this.state.number;
        number.correct = correct;
        history.unshift(number);
        this.setState({ history, correctCount: history.filter(i => i.correct).length, incorrectCount: history.filter(i => !i.correct).length });
        this.load();
    }

    render() {
        return (
            <div>
                {!this.state.started && <div>
                    <Row>
                        <Col xs={0} lg={3}></Col>
                        <Col xs={12} lg={6}>
                            <h3 className='text-center'>Counter Pitch Accent Recall Test</h3>
                            <div className="d-grid">
                                <Button disabled={this.state.selectedCounters.length === 0} block variant="primary" onClick={() => this.start()}>Start</Button>
                                <hr />
                            </div>
                        </Col>
                        <Col xs={0} lg={3}></Col>
                    </Row>
                    <Row>
                        <Col xs={12}>
                            <div className='text-center'>
                                <Button variant='secondary' className='m-2' onClick={() => this.deselectAllCounters()}>Deselect All</Button>
                                <Button variant='secondary' className='m-2' onClick={() => this.selectAllCounters()}>Select All</Button>
                                {this.state.allCounters.map(c => <Button className='m-2' active={this.state.selectedCounters.filter(sc => sc.id == c.id).length > 0} onClick={() => this.toggleCounter(c.id)}>{c.name}</Button>)}
                            </div>
                        </Col>
                    </Row>
                </div>}
                {!this.state.number && this.state.started && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}

                {this.state.number && <div>
                    <Row>
                        <Col xs={12} lg={3} className='order-2 order-lg-0 mt-3 mt-lg-0'>
                            <h4 className='text-center'>History</h4>
                            <ListGroup className="overflow-auto hide-scrollbar max-vh-75">
                                {this.state.history.map((item, i) => {
                                    return <ListGroup.Item key={i} variant={item.correct ? 'success' : 'danger'}>{item.accents[0].accent.map(a => Helpers.outputAccentPlainText(a.pronunciation, a.pitchAccent)).join('・')}</ListGroup.Item>;
                                })}
                            </ListGroup>
                        </Col>
                        <Col xs={12} lg={6} className='text-center order-0 order-lg-1'>
                            {this.state.numberHTML && <h2 className='text-center' dangerouslySetInnerHTML={{__html: this.state.numberHTML}}></h2>}
                            {this.state.number && this.state.number.usage && <h6 className='text-center text-muted'>{this.state.number.usage}</h6>}
                            {this.state.answer && <div>
                                <hr />
                                <span className={`fs-5 visual-type-showPitchAccentDrops text-center`} dangerouslySetInnerHTML={{__html: this.state.answer.html}}></span>
                                <audio controls autoPlay>
                                    <source src={`/api/media/nhk/audio/${this.state.answer.soundFile}`} type='audio/mpeg' />
                                </audio>

                                {this.state.otherAnswers.length > 0 && <h4 className='mt-1'>Other Answers:</h4>}
                                {this.state.otherAnswers.map(answer => <div className='d-flex justify-content-between mx-4 mb-1'>
                                    <span className={`fs-5 visual-type-showPitchAccentDrops text-center`} dangerouslySetInnerHTML={{__html: answer.html}}></span>
                                    <audio controls>
                                        <source src={`/api/media/nhk/audio/${answer.soundFile}`} type='audio/mpeg' />
                                    </audio>
                                </div>)}
                            </div>}
                            {!this.state.answer && <div className="d-grid">
                                <Button block variant="primary" onClick={() => this.showAnswer()}>Show Answer</Button>
                            </div>}
                            {this.state.answer && <div className='d-flex justify-content-evenly mt-3'>
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

Counters.contextType = UserContext;
export default Counters;
