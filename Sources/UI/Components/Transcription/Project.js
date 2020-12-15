import { withRouter } from "react-router";
import React, { useState } from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed'
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import Table from 'react-bootstrap/Table';
import YouTube from 'react-youtube';

import AddTargetLanguageModal from "./AddTargetLanguageModal";

const CustomMenu = React.forwardRef(({ children, style, className, 'aria-labelledby': labeledBy }, ref) => {
    const [value, setValue] = useState('');
    return (
        <div ref={ref} style={style} className={className} aria-labelledby={labeledBy}>
            <Form.Control autoFocus className="mx-3 my-2 w-auto" placeholder="Type to filter..." onChange={(e) => setValue(e.target.value)}   value={value} />
            <ul className="list-unstyled my-0">
                {React.Children.toArray(children).filter(child => !value || child.props.children.toLowerCase().startsWith(value))}
            </ul>
          </div>
        );
    },
);

class Project extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            project: null,
            fragments: [],
            selectedBaseLanguage: null,
            selecteTargetTranslation: null,
            showAddTargetLanguageModal: false,
            videoDuration: 0
        };
    }

    componentDidMount() {
        this.loadProject();
    }

    async loadProject() {
        const id = this.props.match.params.id;
        const response = await fetch(`/api/transcription/project/${id}`);
        if (response.ok) {
            const project = await response.json();
            this.setState({
                project,
                fragments: project.fragments,
                selectedBaseTranslation: project.translations.filter(t => t.isOriginal)[0],
                selecteTargetTranslation: project.translations.filter(t => !t.isOriginal)[0]
            });
        }
    }

    toggleAddTargetLanguageModal(show) {
        console.log('will toggle');
        console.log(show);
        this.setState({
            showAddTargetLanguageModal: show
        });
    }

    async addedNewTargetLanguage() {
        await this.loadProject();
        this.toggleAddTargetLanguageModal(false);
    }

    videoOnReady(e) {
        this.setState({
            videoDuration: e.playerInfo.duration
        })
    }

    onStateChange(e) {
        console.log(e);
    }

    formatTime(seconds) {
        if (this.state.videoDuration > 60 * 60) {
            return new Date(seconds * 1000).toISOString().substr(11, 8);
        } else {
            return new Date(seconds * 1000).toISOString().substr(14, 5);
        }
    }

    render() {
        return (
            <div>
                {!this.state.project && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}

                {this.state.project && <div>
                    <h2>{this.state.project.name}</h2>
                    <p><strong>Owner</strong>: {this.state.project.owner.username}</p>
                    <Form.Row className="align-items-center" inline>
                        <Col sm={4}>
                            <InputGroup>
                                <DropdownButton as={InputGroup.Prepend} variant="outline-secondary" title="Base Language" id="input-group-dropdown-1">
                                    {this.state.project.translations.map(translation => {
                                        return <Dropdown.Item active={translation.id == this.state.selectedBaseTranslation.id} href="#">{translation.language.name}</Dropdown.Item>;
                                    })}
                                </DropdownButton>
                                <Form.Control value={this.state.selectedBaseTranslation.language.name} readOnly />
                            </InputGroup>
                        </Col>
                        <i className="bi bi-arrow-bar-right"></i>
                        <Col sm={4}>
                            <InputGroup>
                                <DropdownButton as={InputGroup.Prepend} variant="outline-secondary" title="Target Language" id="input-group-dropdown-1">
                                    {this.state.project.translations.map(translation => {
                                        return <Dropdown.Item href="#">{translation.language.name}</Dropdown.Item>;
                                    })}
                                    <Dropdown.Divider />
                                    <Dropdown.Item onSelect={() => this.toggleAddTargetLanguageModal(true)}>Add Translation</Dropdown.Item>
                                </DropdownButton>
                                <Form.Control value={this.state.selecteTargetTranslation ? this.state.selecteTargetTranslation.language.name : "(None)"} readOnly />
                            </InputGroup>
                        </Col>
                    </Form.Row>
                    <hr />
                    <Row>
                        <Col>
                            <div className="mb-2">
                                <Row>
                                    <Col xs="auto" className="text-center align-self-center">
                                        <Badge variant="primary-inverted">{this.formatTime(0)}</Badge>
                                    </Col>
                                    <Col className="px-0">
                                        <div className="form-control mb-2 no-box-shadow" style={{"caret-color": "#007bff"}} contentEditable>
                                            Test
                                        </div>
                                        <div className="form-control no-box-shadow" style={{"caret-color": "#007bff"}}  contentEditable>
                                            テスト
                                        </div>
                                    </Col>
                                    <Col xs="auto" className="text-center align-self-center">
                                        <Badge variant="primary-inverted">{this.formatTime(5)}</Badge>
                                    </Col>
                                </Row>
                                <hr />
                            </div>
                            <Button variant="primary" block>Add Fragment</Button>
                        </Col>
                        <Col>
                            <ResponsiveEmbed aspectRatio="16by9">
                                <YouTube videoId={this.state.project.youtubeID} onReady={(e) => this.videoOnReady(e)} onStateChange={(e) => this.onStateChange(e)} />
                            </ResponsiveEmbed>
                        </Col>
                    </Row>
                    <AddTargetLanguageModal project={this.state.project} show={this.state.showAddTargetLanguageModal} onHide={() => this.toggleAddTargetLanguageModal(false)} didCancele={() => this.toggleAddTargetLanguageModal(false)} onFinish={() => this.addedNewTargetLanguage()} />
                </div>}
            </div>
        )
    }
}

export default withRouter(Project);
