import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';
import { withRouter } from 'react-router';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import ListGroup from 'react-bootstrap/ListGroup';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import YouTube from 'react-youtube';

import Helpers from './../Helpers';

class PitchAccentMinimalPairsPerception extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            soundFile: null,
            options: [],
            tick: 0,
            response: null,
            expiresAt: null,
            secondsRemaining: 0
        };
        this.handleMessage = this.handleMessage.bind(this);
        this.updateTimeout = this.updateTimeout.bind(this);
    }

    componentDidMount() {
        if (this.props.ws) {
            this.props.ws.addEventListener('message', this.handleMessage);
            this.interval = setInterval(this.updateTimeout, 500);
        }
    }

    componentWillUnmount() {
        if (this.props.ws) {
            this.props.ws.removeEventListener('message', this.handleMessage);
        }

        if (this.interval) {
            clearInterval(this.interval);
            this.interval = null;
        }
    }

    componentDidUpdate(prevProps) {
        if (prevProps.ws != this.props.ws) {
            if (prevProps.ws) {
                prevProps.ws.removeEventListener('message', this.handleMessage);
            }
            if (this.props.ws) {
                this.props.ws.addEventListener('message', this.handleMessage);
            }

            if (!this.interval) {
                this.interval = setInterval(this.updateTimeout, 500);
            }
        }
    }

    start() {
        this.props.ws.send(JSON.stringify({
            name: 'startGame',
            data: {},
            connectionID: this.props.connectionID
        }));
    }

    handleMessage(event) {
        const message = JSON.parse(event.data);
        const name = message.name;
        const data = message.data;
        console.log(message);
        if (name === 'minimalPair') {
            this.setState({
                soundFile: data.soundFile,
                options: data.options,
                tick: data.tick,
                response: null,
                expiresAt: new Date(data.expiresAt)
            });
            this.props.onPlayAudio(`/api/media/nhk/audio/${data.soundFile}`);
        }
    }

    winner() {
        return this.props.lobby.users.reduce((prev, current) => {
            return (prev.score > current.score) ? prev : current
        });
    }

    updateTimeout() {
        if (!this.state.expiresAt) {
            return;
        }

        const secondsRemaining = Math.max(0, this.state.expiresAt.getTime() - (new Date()).getTime()) / 1000;
        this.setState({ secondsRemaining });
    }

    select(option) {
        if (this.props.lobby.state !== 'inProgress') {
            return;
        }

        this.setState({ response: option.pitchAccent });
        this.props.ws.send(JSON.stringify({
            name: 'userResponse',
            data: { pitchAccent: option.pitchAccent, tick: this.state.tick },
            connectionID: this.props.connectionID
        }));
    }

    render() {
        console.log(this.props.lobby.state === 'inProgress' && this.state.soundFile && this.state.response === null);
        return (
            <div className='flex-fill d-flex justify-content-center align-items-center flex-column'>
                {!this.props.user.isOwner && this.props.lobby.state === 'notStarted' && <h1 className='text-center'>Waiting on lobby owner to start game...<br /><Spinner animation="border" variant="secondary" /></h1>}
                {this.props.user.isOwner && this.props.lobby.state === 'notStarted' && <Button className='col-5' variant="primary" onClick={() => this.start()}>Start</Button>}

                {this.props.lobby.state === 'inProgress' && this.state.soundFile && this.state.response === null && <div className='col-12 text-center position-relative'>
                    <span className={`fs-5 position-absolute${this.state.secondsRemaining < 15 ? ' text-danger' : ''}`} style={{ left: 0, top: 0 }}>{this.state.secondsRemaining.toFixed(0)}</span>
                    <span className='cursor-pointer fs-1' onClick={() => this.props.onPlayAudio(`/api/media/nhk/audio/${this.state.soundFile}`)}><i class="bi bi-play-btn-fill"></i></span>

                    <hr />
                    <Row>
                        {this.state.options.map((option, i) => {
                            return <Col key={i}>
                                <div className="d-grid">
                                    <Button variant='primary' className="mt-3" onClick={() => this.select(option)}>{Helpers.outputAccentPlainText(option.accent.pronunciation, option.accent.pitchAccent)}</Button>
                                </div>
                            </Col>;
                        })}
                    </Row>
                </div>}
                {this.props.lobby.state === 'inProgress' && (!this.state.soundFile || this.state.response !== null) && <h1 className='text-center'><Spinner animation="border" variant="secondary" /></h1>}

                {this.props.lobby.state === 'finished' && <h1 className='text-center'><i class='bi bi-trophy-fill'></i><br />{this.winner().name}</h1>}
                {this.props.user.isOwner && this.props.lobby.state === 'finished' && <Button className='col-5' variant="primary" onClick={() => this.start()}>Go Again</Button>}
            </div>
        );
    }
}

export default PitchAccentMinimalPairsPerception;
