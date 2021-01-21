import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';
import dashjs from 'dashjs';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Breadcrumb from 'react-bootstrap/Breadcrumb';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import ListGroup from 'react-bootstrap/ListGroup';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
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
                    url: `/api/media/plex/resource/${this.props.server.clientIdentifier}/stream/${child.ratingKey}?protocol=hls`,
                    type: 'application/vnd.apple.mpegurl',
                    shortType: 'hls',
                    base: `/api/media/plex/resource/${this.props.server.clientIdentifier}/stream/${child.ratingKey}`
                },
                {
                    url: `/api/media/plex/resource/${this.props.server.clientIdentifier}/stream/${child.ratingKey}?protocol=dash`,
                    type: 'application/dash+xml',
                    shortType: 'dash',
                    base: `/api/media/plex/resource/${this.props.server.clientIdentifier}/stream/${child.ratingKey}`
                }
            ];
            this.props.onPlayMedia(media);
        }
    }

    breadcrumb() {
        return {
            hide: () => this.setState({ child: null }),
            name: this.props.section.title
        };
    }

    render() {
        if (this.state.child) {
            return (
                <SectionChildrenList breadcrumbs={[...this.props.breadcrumbs, this.breadcrumb()]} onPlayMedia={this.props.onPlayMedia} section={this.state.child} server={this.props.server} />
            );
        } else {
            if (this.props.section.type === 'episode' || this.props.section.type === 'movie') {
                return (
                    <div>
                        <Breadcrumb>
                            {this.props.breadcrumbs.map((b, i) => (
                                <Breadcrumb.Item key={i} onClick={() => b.hide()}>{b.name}</Breadcrumb.Item>
                            ))}
                            <Breadcrumb.Item active>{this.props.section.title}</Breadcrumb.Item>
                        </Breadcrumb>
                        {this.props.section.type === 'episode' && <small>Episode {this.props.section.index}</small>}
                        <h4>{this.props.section.title}</h4>
                    </div>
                );
            } else {
                return (
                    <div>
                        <Breadcrumb>
                            {this.props.breadcrumbs.map((b, i) => (
                                <Breadcrumb.Item key={i} onClick={() => b.hide()}>{b.name}</Breadcrumb.Item>
                            ))}
                            <Breadcrumb.Item active>{this.props.section.title}</Breadcrumb.Item>
                        </Breadcrumb>
                        <h4>{this.props.section.title}</h4>
                        <ListGroup>
                            {this.state.children.map((s, i) => (<ListGroup.Item className='d-flex justify-content-between align-items-center' key={i}  action onClick={() => this.playMedia(s)}>
                                <div>
                                    {s.title}
                                    <br />
                                    <small>{s.type === 'episode' && `Episode ${s.index}`}</small>
                                </div>

                                {(s.type === 'movie' || s.type === 'episode') && s.viewCount && s.viewCount > 0 && <i class='bi bi-check fs-3 text-success'></i>}
                            </ListGroup.Item>))}
                        </ListGroup>
                    </div>
                );
            }
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

    breadcrumb() {
        return {
            hide: () => this.setState({ section: null }),
            name: this.props.server.name
        };
    }

    render() {
        if (this.state.section) {
            return (
                <SectionChildrenList breadcrumbs={[...this.props.breadcrumbs, this.breadcrumb()]} onPlayMedia={this.props.onPlayMedia} section={this.state.section} server={this.props.server} />
            );
        } else {
            return (
                <div>
                    <Breadcrumb>
                        {this.props.breadcrumbs.map((b, i) => (
                            <Breadcrumb.Item key={i} onClick={() => b.hide()}>{b.name}</Breadcrumb.Item>
                        ))}
                        <Breadcrumb.Item active>{this.props.server.name}</Breadcrumb.Item>
                    </Breadcrumb>
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

    breadcrumb() {
        return {
            hide: () => this.setState({ server: null }),
            name: 'Servers'
        };
    }

    render() {
        if (this.state.server) {
            return (
                <SectionList breadcrumbs={[this.breadcrumb()]} onPlayMedia={this.props.onPlayMedia} server={this.state.server} />
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
            media: [],
            useDash: false
        };
        this.playerRef = React.createRef();
    }

    componentDidMount() {
        this.setState({
            useDash: typeof(window.MediaSource || window.WebKitMediaSource) === 'function'
        });
    }

    toggleConfigureServer(show) {
        this.setState({ showConfigureServer: show });
    }

    startCapture(e) {
        e.preventDefault();
        this.setState({ isRecording: true, startTime: this.state.playerRef.currentTime });
        this.state.playerRef.play();
    }

    keyPress(e) {
        if (e.which === 32) {
            e.preventDefault();
            if (this.state.playerRef.paused) {
                this.state.playerRef.play();
            } else {
                this.state.playerRef.pause();
            }
        } else if (e.which === 39) {
            this.state.playerRef.currentTime += 10;
        } else if (e.which === 37) {
            this.state.playerRef.currentTime = max(0, this.state.playerRef.currentTime - 10);
        }
    }

    async endCapture() {
        this.state.playerRef.pause();
        this.setState({ isRecording: false, isSubmitting: true, lastFile: null });
        const startTime = this.state.startTime;
        const endTime = this.state.playerRef.currentTime;
        const response = await fetch(`${this.state.media[0].base}/capture`, {
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

    async fastestURL(urls) {
        console.log('fastest of: ');
        console.log(urls);
        return urls[0];
    }

    async parseMedia(medias) {
        const self = this;
        const promises = medias.map(async (m) => {
            const response = await fetch(m.url);
            const urls = await response.json();
            const url = await self.fastestURL(urls);
            return {
                src: url,
                type: m.type,
                base: m.base
            }
        });
        const result = await Promise.all(promises);
        return result.filter(m => m.src);
    }

    async playMedia(medias) {
        const compatibleMedias = medias.filter(m => this.state.useDash ? (m.shortType === 'dash') : (m.shortType !== 'dash'));
        const parsedMedias = await this.parseMedia(compatibleMedias);
        this.setState({ media: parsedMedias });
        if (this.state.useDash && parsedMedias.length > 0) {
            if (this.dashPlayer) {
                this.dashPlayer.attachSource(parsedMedias[0].src);
            } else {
                this.dashPlayer = dashjs.MediaPlayer().create();
                this.dashPlayer.initialize(this.playerRef.current, parsedMedias[0].src, true);
            }
        }
    }

    canPlay(e) {
        this.setState({ playerRef: e.target });
    }

    render() {
        return (
            <UserContext.Consumer>{user => (
                <Row>
                    <Col xs={12} md={7}>
                        <div className={this.state.media.length > 0 ? '' : 'd-none'} onKeyPress={(e) => this.keyPress(e)}>
                            <video ref={this.playerRef} width="100%" controls autoPlay onCanPlay={(e) => this.canPlay(e)}>
                                {this.state.media.map((m, i) => (
                                    <source src={m.src} type={m.type} />
                                ))}
                            </video>
                            <hr />
                        </div>
                        {user.plexAuth && <ServerList onPlayMedia={(m) => this.playMedia(m)} user={user} />}
                        <hr />
                        <Button variant='secondary' className='mt-0 col-12' onClick={() => this.setState({ showConfigureServer: true })}>Configure Server</Button>
                    </Col>

                    <Col xs={12} md={5}>
                        <Button onTouchStart={(e) => this.startCapture(e)} onMouseDown={(e) => this.startCapture(e)} onTouchEnd={() => this.endCapture()} onMouseUp={() => this.endCapture()} className='col-12 mt-3 mt-md-0 user-select-none' variant={this.state.isRecording ? 'warning' : (this.state.isSubmitting ? 'secondary' : 'danger')} type="submit" disabled={this.state.isSubmitting || this.state.media.length === 0}>
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
