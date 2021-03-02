import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

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

import Helpers from './../Helpers';

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
            const sessionID = Helpers.randomString(24);
            const media = [
                {
                    url: `/api/media/plex/resource/${this.props.server.clientIdentifier}/stream/${child.ratingKey}?protocol=hls&sessionID=${sessionID}`,
                    timelineURL: `/api/media/plex/resource/${this.props.server.clientIdentifier}/timeline/${child.ratingKey}?sessionID=${sessionID}`,
                    type: 'application/vnd.apple.mpegurl',
                    shortType: 'hls',
                    base: `/api/media/plex/resource/${this.props.server.clientIdentifier}/stream/${child.ratingKey}`,
                    sessionID,
                    duration: child.duration
                },
                {
                    url: `/api/media/plex/resource/${this.props.server.clientIdentifier}/stream/${child.ratingKey}?protocol=dash&sessionID=${sessionID}`,
                    timelineURL: `/api/media/plex/resource/${this.props.server.clientIdentifier}/timeline/${child.ratingKey}?sessionID=${sessionID}`,
                    type: 'application/dash+xml',
                    shortType: 'dash',
                    base: `/api/media/plex/resource/${this.props.server.clientIdentifier}/stream/${child.ratingKey}`,
                    sessionID,
                    duration: child.duration
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

export default ServerList;
