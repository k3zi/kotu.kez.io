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

class Transcribe extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            externalFileID: null,
            tick: 0,
            response: '',
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
        if (name === 'subtitle') {
            this.setState({
                externalFileID: data.externalFileID,
                tick: data.tick,
                response: '',
                expiresAt: new Date(data.expiresAt)
            });
            this.props.onPlayAudio(`/api/media/external/audio/${data.externalFileID}`);
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

    submit(e) {
        e.preventDefault();
        if (this.props.lobby.state !== 'inProgress') {
            return;
        }

        const data = Object.fromEntries(new FormData(e.target));
        const response = data.response || '';
        this.setState({ response });
        this.props.ws.send(JSON.stringify({
            name: 'userResponse',
            data: { text: response, tick: this.state.tick },
            connectionID: this.props.connectionID
        }));
        e.target.reset();
    }

    render() {
        return (
            <div className='flex-fill d-flex justify-content-center align-items-center flex-column'>
                {!this.props.user.isOwner && this.props.lobby.state === 'notStarted' && <h1 className='text-center'>Waiting on lobby owner to start game...<br /><Spinner animation="border" variant="secondary" /></h1>}
                {this.props.user.isOwner && this.props.lobby.state === 'notStarted' && <Button className='col-5' variant="primary" onClick={() => this.start()}>Start</Button>}

                {this.props.lobby.state === 'inProgress' && this.state.externalFileID && this.state.response.length === 0 && <div className='col-12 text-center position-relative'>
                    <span className={`fs-5 position-absolute${this.state.secondsRemaining < 15 ? ' text-danger' : ''}`} style={{ left: 0, top: 0 }}>{this.state.secondsRemaining.toFixed(0)}</span>
                    <span className='cursor-pointer fs-1' onClick={() => this.props.onPlayAudio(`/api/media/external/audio/${this.state.externalFileID}`)}><i class="bi bi-play-btn-fill"></i></span>
                    <hr />

                    <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Control defaultValue={this.state.response} autoComplete='off' type='text' name={'response'} placeholder='Type what you hear' />
                    </Form>
                </div>}
                {this.props.lobby.state === 'inProgress' && (!this.state.externalFileID || this.state.response.length > 0) && <h1 className='text-center'><Spinner animation="border" variant="secondary" /></h1>}

                {this.props.lobby.state === 'finished' && <h1 className='text-center'><i class='bi bi-trophy-fill'></i><br />{this.winner().name}</h1>}
                {this.props.user.isOwner && this.props.lobby.state === 'finished' && <Button className='col-5' variant="primary" onClick={() => this.start()}>Go Again</Button>}
            </div>
        );
    }
}

export default Transcribe;
