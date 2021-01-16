import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import ListGroup from 'react-bootstrap/ListGroup';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

import CreateNoteForm from './../Flashcard/Modals/CreateNoteForm';
import ConfigurePlexServer from './ConfigurePlexServer';

import UserContext from './../Context/User';

class SectionChildrenList extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            children: [],
            child: null
        };
    }

    componentDidMount() {
        this.update();
    }

    async update() {
        const response = await fetch(`/api/media/plex/resource/${this.props.server.clientIdentifier}/section/${encodeURIComponent((this.props.section.path || this.props.section.key) + '/all')}`);
        if (!response.ok) {
            return;
        }
        const children = await response.json();
        this.setState({ children });
    }

    playMedia(child) {
        this.setState({ child });
        if ((child.type === 'episode' || child.type === 'movie') && child.Media) {
            const media = [
                {
                    src: `/api/media/plex/resource/${this.props.server.clientIdentifier}/stream/${child.ratingKey}`,
                    type: 'application/vnd.apple.mpegurl'
                }
            ];
            this.props.onPlayMedia(media);
        }
    }

    render() {
        if (this.state.child) {
            if (this.state.child.type === 'show' || this.state.child.type === 'season') {
                return (
                    <SectionChildrenList onPlayMedia={this.props.onPlayMedia} section={this.state.child} server={this.props.server} />
                );
            } else if (this.state.child.Media) {
                return (
                    <div>
                        <h4>{this.state.child.title}</h4>
                    </div>
                );
            } else {
                return (
                    <div>
                        <h4>{this.state.child.title}</h4>
                    </div>
                );
            }
        } else {
            return (
                <div>
                    <h4>{this.props.section.title}</h4>
                    <ListGroup>
                        {this.state.children.map((s, i) => (<ListGroup.Item key={i}  action onClick={() => this.playMedia(s)}>
                            {s.title}
                        </ListGroup.Item>))}
                    </ListGroup>
                </div>
            );
        }
    }

}

class SectionList extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            sections: [],
            section: null
        };
    }

    componentDidMount() {
        this.update();
    }

    async update() {
        const response = await fetch(`/api/media/plex/resource/${this.props.server.clientIdentifier}/sections`);
        if (!response.ok) {
            return;
        }
        const sections = await response.json();
        this.setState({ sections });
    }

    render() {
        if (this.state.section) {
            return (
                <SectionChildrenList onPlayMedia={this.props.onPlayMedia} section={this.state.section} server={this.props.server} />
            );
        } else {
            return (
                <div>
                    <h4>{this.props.server.name}</h4>
                    <ListGroup>
                        {this.state.sections.map((s, i) => (<ListGroup.Item key={i}  action onClick={() => this.setState({ section: s})}>
                            {s.title}
                        </ListGroup.Item>))}
                    </ListGroup>
                </div>
            );
        }
    }

}

class ServerList extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            servers: [],
            server: null
        };
    }

    componentDidMount() {
        this.update();
    }

    async update() {
        const response = await fetch(`/api/media/plex/resources`);
        if (!response.ok) {
            return;
        }
        const resources = await response.json();
        const servers = resources.filter(r => r.provides.includes('server'));
        this.setState({ servers });
    }

    render() {
        if (this.state.server) {
            return (
                <SectionList onPlayMedia={this.props.onPlayMedia} server={this.state.server} />
            );
        } else {
            return (
                <div>
                    <h4>Servers</h4>
                    <ListGroup>
                        {this.state.servers.map((s, i) => (<ListGroup.Item key={i}  action onClick={() => this.setState({ server: s})}>
                            {s.name}
                        </ListGroup.Item>))}
                    </ListGroup>
                </div>
            );
        }
    }

}

class PlexPlayer extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            playerRef: null,
            isRecording: false,
            isSubmitting: false,
            lastFile: null,
            showConfigureServer: false,
            media: []
        };
    }

    toggleConfigureServer(show) {
        this.setState({ showConfigureServer: show });
    }

    startCapture(e) {
        e.preventDefault();
        this.setState({ isRecording: true, startTime: this.state.playerRef.currentTime });
        this.state.playerRef.play();
    }

    async endCapture() {
        this.state.playerRef.pause();
        this.setState({ isRecording: false, isSubmitting: true, lastFile: null });
        const startTime = this.state.startTime;
        const endTime = this.state.playerRef.currentTime;
        const response = await fetch(`${this.state.media[0].src}/capture`, {
            method: 'POST',
            body: JSON.stringify({
                startTime,
                endTime
            }),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        if (response.ok) {
            function typeInTextarea(newText) {
                const element = document.activeElement;
                const selection = window.getSelection();
                if (!selection.isCollapsed) return;

                const text = element.innerText;
                const before = text.substring(0, selection.focusOffset);
                const after  = text.substring(selection.focusOffset, text.length);
                element.innerText = before + newText + after;
                const event = new Event('change');
                element.dispatchEvent(event);
            }
            const result = await response.json();
            this.setState({ lastFile: result, isSubmitting: false });
            if (document.hasFocus() && document.activeElement.contentEditable == 'true') {
                setTimeout(() => {
                    typeInTextarea(`[audio: ${result.id}]`);
                }, 100);
            }
        } else {
            this.setState({ isSubmitting: false });
        }
    }

    playMedia(media) {
        this.setState({ media });
    }

    canPlay(e) {
        this.setState({ playerRef: e.target });
    }

    render() {
        return (
            <UserContext.Consumer>{user => (
                <Row>
                    <Col xs={12} md={7}>
                        {this.state.media.length > 0 && <>
                            <video width="100%" controls autoPlay onCanPlay={(e) => this.canPlay(e)}>
                                {this.state.media.map((m, i) => (
                                    <source src={m.src} type={m.type} />
                                ))}
                            </video>
                            <hr />
                        </>}
                        {user.plexAuth && <ServerList onPlayMedia={(m) => this.playMedia(m)} user={user} />}
                        <hr />
                        <Button variant='secondary' className='mt-0 col-12' onClick={() => this.setState({ showConfigureServer: true })}>Configure Server</Button>
                    </Col>

                    <Col xs={12} md={5}>
                        <Button onMouseDown={(e) => this.startCapture(e)} onMouseUp={() => this.endCapture()} className='col-12 mt-3 mt-md-0' variant={this.state.isRecording ? 'warning' : (this.state.isSubmitting ? 'secondary' : 'danger')} type="submit" disabled={this.state.isSubmitting || this.state.media.length === 0}>
                            {this.state.isRecording ? 'Release to Capture' : (this.state.isSubmitting ? 'Capturing' : 'Hold to Record')}
                        </Button>
                        {this.state.lastFile && <Alert dismissible onClose={() => this.setState({ lastFile: null })} className='mt-3' variant='primary'>Audio Embed Code: <pre className='mb-0 user-select-all'>[audio: {this.state.lastFile.id}]</pre></Alert>}
                        <CreateNoteForm className='mt-3' onSuccess={() => { }} />
                    </Col>
                    <ConfigurePlexServer show={this.state.showConfigureServer} onHide={() => this.toggleConfigureServer(false)} onSuccess={() => this.toggleConfigureServer(false)} />
                </Row>
            )
        }</UserContext.Consumer>);
    }
}

export default PlexPlayer;
