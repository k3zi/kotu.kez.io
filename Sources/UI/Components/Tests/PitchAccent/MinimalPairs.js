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

class MinimalPairs extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            minimalPair: null,
            pairIndex: null,
            selectedIndex: null,
            started: false,
            history: []
        };
    }

    componentDidMount() {
    }

    async start() {
        this.setState({ started: true });
        this.load();
    }

    async load() {
        const response = await fetch('/api/tests/pitchAccent/minimalPairs/random');
        if (response.ok) {
            const minimalPair = await response.json();
            this.setState({ minimalPair, pairIndex: Math.floor(Math.random() * minimalPair.pairs.length) });
        }
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
                output += '＼';
            }
        }

        return output;
    }

    selectIndex(index) {
        const correct = index == this.state.pairIndex;
        this.setState({ selectedIndex: index });

        setTimeout(() => {
            const history = this.state.history;
            const pair = this.state.minimalPair.pairs[this.state.pairIndex];
            const entry = pair.entries[0];
            history.unshift({
                correct,
                pair,
                type: (pair.pitchAccent == 0 || pair.pitchAccent == entry.moraCount) ? 'Heiban / Odaka' : (pair.pitchAccent == 1 ? 'Atamadaka' : 'Nakadaka')
            });
            const statistics = {
                heiban: history.filter(i => i.type == 'Heiban / Odaka'),
                atamadaka: history.filter(i => i.type == 'Atamadaka'),
                nakadaka: history.filter(i => i.type == 'Nakadaka')
            };
            statistics.heibanCorrect = statistics.heiban.filter(i => i.correct);
            statistics.atamadakaCorrect = statistics.atamadaka.filter(i => i.correct);
            statistics.nakadakaCorrect = statistics.nakadaka.filter(i => i.correct);
            this.setState({
                minimalPair: null,
                selectedIndex: null,
                history,
                statistics
            });
            this.load();
        }, 1000);
    }

    render() {
        return (
            <div>
                {!this.state.started && <Row>
                    <Col xs={0} lg={3}></Col>
                    <Col xs={12} lg={6}>
                        <h3 className='text-center'>Minimal Pairs Pitch Accent Perception Test</h3>
                        <div className="d-grid">
                            <Button block variant="primary" onClick={() => this.start()}>Start</Button>
                        </div>
                    </Col>
                    <Col xs={0} lg={3}></Col>
                </Row>}
                {!this.state.minimalPair && this.state.started && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}

                {this.state.minimalPair && <div>
                    <Row>
                        <Col xs={12} lg={3} className='order-2 order-lg-0 mt-3 mt-lg-0'>
                            <h4 className='text-center'>History</h4>
                            <ListGroup className="overflow-auto hide-scrollbar max-vh-75">
                                {this.state.history.map((item, i) => {
                                    return <ListGroup.Item key={i} variant={item.correct ? 'success' : 'danger'}>{this.accentOutput(item.pair.entries[0].accents[0].accent[0].pronunciation, item.pair.entries[0].accents[0].accent[0].pitchAccent)}</ListGroup.Item>;
                                })}
                            </ListGroup>
                        </Col>
                        <Col xs={12} lg={6} className='text-center order-0 order-lg-1'>
                            <h3 className='text-center'>{this.state.minimalPair.kana}</h3>
                            <audio controls autoPlay>
                                <source src={`/api/media/nhk/audio/${this.state.minimalPair.pairs[this.state.pairIndex].soundFile}`} type='audio/mpeg' />
                            </audio>
                            <hr />
                            <Row>
                                {this.state.minimalPair.pairs.map((pair, i) => {
                                    return <Col key={i}>
                                        <div className="d-grid">
                                            <Button block variant={this.state.selectedIndex === i ? (this.state.pairIndex === i ? 'success' : 'danger') : (this.state.selectedIndex == null ? 'primary' : (this.state.pairIndex === i ? 'success' : 'danger'))} className="mt-3" onClick={() => this.selectIndex(i)}>{this.accentOutput(pair.entries[0].accents[0].accent[0].pronunciation, pair.entries[0].accents[0].accent[0].pitchAccent)}</Button>
                                        </div>
                                    </Col>;
                                })}
                            </Row>
                        </Col>
                        <Col xs={12} lg={3} className='order-1 order-lg-2 mt-3 mt-lg-0'>
                            <h4 className='text-center'>Statistics</h4>
                            {this.state.statistics && <div>
                                <strong>Heiban / Odaka:</strong> {this.state.statistics.heibanCorrect.length} of {this.state.statistics.heiban.length} ({this.state.statistics.heiban.length == 0 ? '0' : Math.round((this.state.statistics.heibanCorrect.length / this.state.statistics.heiban.length) * 100)}%)
                                <br />
                                <strong>Atamadaka:</strong> {this.state.statistics.atamadakaCorrect.length} of {this.state.statistics.atamadaka.length} ({this.state.statistics.atamadaka.length == 0 ? '0' :Math.round((this.state.statistics.atamadakaCorrect.length / this.state.statistics.atamadaka.length) * 100)}%)
                                <br />
                                <strong>Nakadaka:</strong> {this.state.statistics.nakadakaCorrect.length} of {this.state.statistics.nakadaka.length} ({this.state.statistics.nakadaka.length == 0 ? '0' :Math.round((this.state.statistics.nakadakaCorrect.length / this.state.statistics.nakadaka.length) * 100)}%)
                            </div>}
                        </Col>
                    </Row>
                </div>}
            </div>
        );
    }
}

export default MinimalPairs;
