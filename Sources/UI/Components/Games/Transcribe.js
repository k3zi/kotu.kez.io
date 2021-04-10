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
            response: ''
        };
        this.handleMessage = this.handleMessage.bind(this);
        this.audioRef = React.createRef();
    }

    componentDidMount() {
        if (this.props.ws) {
            this.props.ws.addEventListener('message', this.handleMessage);
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
                response: ''
            });
            this.props.onPlayAudio(`/api/media/external/audio/${data.externalFileID}`);
            if (this.audioRef.current) {
                this.audioRef.current.pause();
                this.audioRef.current.load();
            }
        }
    }

    winner() {
        return this.props.lobby.users.reduce((prev, current) => {
            return (prev.score > current.score) ? prev : current
        });
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

                {this.props.lobby.state === 'inProgress' && this.state.externalFileID && this.state.response.length === 0 && <div className='col-12 text-center'>
                    <audio controls ref={this.audioRef}>
                        <source src={`/api/media/external/audio/${this.state.externalFileID}`} type='audio/mpeg' />
                    </audio>
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
