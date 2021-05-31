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
        const response = await fetch('/api/tests/syllabary/minimalPairs/random');
        if (response.ok) {
            const minimalPair = await response.json();
            this.setState({ minimalPair, pairIndex: Math.floor(Math.random() * minimalPair.pairs.length) });
        }
    }

    contrastTypes() {
        return ['tsuContrastSu', 'doContrastRo', 'daContrastRa', 'deContrastRe', 'giContrastNi', 'geContrastNe', 'shortContrastLongVowel', 'shortContrastLongConsonant'];
    }

    contrastTypeDescription(contrastType) {
        return {
            'tsuContrastSu': 'ツ vs ス',
            'doContrastRo': 'ド vs ロ',
            'daContrastRa': 'ダ vs ラ',
            'deContrastRe': 'デ vs レ',
            // 'giContrastNi': 'ギ vs ニ',
            // 'geContrastNe': 'ゲ vs ネ',
            'shortContrastLongVowel': 'Short vs Long Vowel',
            'shortContrastLongConsonant': 'Short vs Long Consonant'
        }[contrastType];
    }

    selectIndex(index) {
        const correct = index == this.state.pairIndex;
        this.setState({ selectedIndex: index });

        setTimeout(() => {
            const history = this.state.history;
            const pair = this.state.minimalPair.pairs[this.state.pairIndex];
            history.unshift({
                correct,
                pair,
                type: this.state.minimalPair.kind
            });
            const statistics = {};
            for (let contrastType of this.contrastTypes()) {
                const all = history.filter(i => i.type === contrastType);
                statistics[contrastType] = {
                    all: all,
                    correct: all.filter(i => i.correct)
                };
            }
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
                        <h3 className='text-center'>Syllabary Minimal Pairs Perception Test</h3>
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
                                    return <ListGroup.Item key={i} variant={item.correct ? 'success' : 'danger'}>{item.pair.accents[0].accent[0].pronunciation}</ListGroup.Item>;
                                })}
                            </ListGroup>
                        </Col>
                        <Col xs={12} lg={6} className='text-center order-0 order-lg-1'>
                            <h3 className='text-center'>{this.state.minimalPair.kana}</h3>
                            <audio controls autoPlay>
                                <source src={`/api/media/nhk/audio/${this.state.minimalPair.pairs[this.state.pairIndex].accents[0].soundFile}`} type='audio/mpeg' />
                            </audio>
                            <hr />
                            <Row>
                                {this.state.minimalPair.pairs.map((pair, i) => {
                                    return <Col key={i}>
                                        <div className="d-grid">
                                            <Button block variant={this.state.selectedIndex === i ? (this.state.pairIndex === i ? 'success' : 'danger') : (this.state.selectedIndex == null ? 'primary' : (this.state.pairIndex === i ? 'success' : 'danger'))} className="mt-3" onClick={() => this.selectIndex(i)}>{pair.accents[0].accent[0].pronunciation}</Button>
                                        </div>
                                    </Col>;
                                })}
                            </Row>
                        </Col>
                        <Col xs={12} lg={3} className='order-1 order-lg-2 mt-3 mt-lg-0'>
                            <h4 className='text-center'>Statistics</h4>
                            {this.state.statistics && <div>
                                {this.contrastTypes().map((type, i) => {
                                    return <>
                                        {i != 0 && <br />}
                                        <strong>{this.contrastTypeDescription(type)}:</strong> {this.state.statistics[type].correct.length} of {this.state.statistics[type].all.length} ({this.state.statistics[type].all.length == 0 ? '0' : Math.round((this.state.statistics[type].correct.length / this.state.statistics[type].all.length) * 100)}%)
                                    </>
                                })}
                            </div>}
                        </Col>
                    </Row>
                </div>}
            </div>
        );
    }
}

export default MinimalPairs;
