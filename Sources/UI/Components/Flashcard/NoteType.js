import { withRouter } from 'react-router';
import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import AceEditor from 'react-ace';
import 'ace-builds/webpack-resolver';
import 'ace-builds/src-noconflict/mode-css';
import 'ace-builds/src-noconflict/mode-html';
import 'ace-builds/src-noconflict/theme-github';
import 'ace-builds/src-noconflict/ext-language_tools';

ace.config.set('basePath', '/generated');

import _ from 'underscore';
import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import Tab from 'react-bootstrap/Tab';
import Tabs from 'react-bootstrap/Tabs';
import Table from 'react-bootstrap/Table';

import AddCardTypeModal from './Modals/AddCardTypeModal';
import DeleteFieldModal from './Modals/DeleteFieldModal';
import CreateFieldModal from './Modals/CreateFieldModal';

import scoper from './scoper';

class NoteType extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showCreateFieldModal: false,
            showDeleteFieldModal: null,
            showAddCardTypeModal: false,
            noteType: null,
            fields: [],
            cardTypes: []
        };

        this.frontPreviewRef = React.createRef();
        this.backPreviewRef = React.createRef();
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const id = this.props.match.params.id;
        const response = await fetch(`/api/flashcard/noteType/${id}`);
        if (response.ok) {
            const noteType = await response.json();
            const selectedCardType = noteType.cardTypes.filter(t => this.state.selectedCardType && t.id === this.state.selectedCardType.id)[0] || noteType.cardTypes[0];
            this.setState({ noteType, fields: noteType.fields, cardTypes: noteType.cardTypes, selectedCardType });
        }
    }

    async toggleCreateFieldModal(show) {
        this.setState({
            showCreateFieldModal: show
        });
        await this.load();
    }

    async showDeleteFieldModal(field) {
        this.setState({
            showDeleteFieldModal: field
        });
        await this.load();
    }

    async toggleAddCardType(show) {
        this.setState({
            showAddCardTypeModal: show
        });
        await this.load();
    }

    async handleChange(item, text) {
        this.state.selectedCardType[item] = text;
        await fetch(`/api/flashcard/noteType/${this.state.noteType.id}/cardType/${this.state.selectedCardType.id}`, {
            method: 'PUT',
            body: JSON.stringify(this.state.selectedCardType),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        this.setState({ selectedCardType: this.state.selectedCardType });
    }

    htmlFor(cardType, html, id) {
        let result = `
        <div id="${`card_${id}`}">
            <style>
                ${scoper(cardType.css, `#card_${id}`)}
            </style>

            <div id="card">
                <div id="${id}">
                    ${cardType[html]}
                </div>
            </div>
        </div>
        `;

        if (id !== 'front') {
            result = result.replace(/{{FrontSide}}/g, cardType.frontHTML);
        }

        return result;
    }

    render() {
        return (
            <div>
                {!this.state.noteType && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}

                {this.state.noteType && <div>
                    <h2>Note Type <small className="text-muted">{this.state.noteType.name}</small></h2>
                    <hr/>
                    <Row>
                        <Col>
                            <h4>Card Template</h4>
                            <InputGroup className="mb-3">
                                <Form.Control value={this.state.selectedCardType ? this.state.selectedCardType.name : '(None)'} readOnly />
                                <DropdownButton variant="outline-secondary" title="Card Type" id="input-group-dropdown-1">
                                    {this.state.cardTypes.map(cardType => {
                                        return <Dropdown.Item active={this.state.selectedCardType && cardType.id == this.state.selectedCardType.id} onSelect={() => this.setState({ selectedCardType: cardType })}>{cardType.name}</Dropdown.Item>;
                                    })}
                                    <Dropdown.Divider />
                                    <Dropdown.Item onSelect={() => this.toggleAddCardType(true)}>Add Card Type</Dropdown.Item>
                                </DropdownButton>
                            </InputGroup>

                            {this.state.selectedCardType && <Row>
                                <Col>
                                    <Tabs defaultActiveKey="front" id="code-tabs">
                                        <Tab eventKey="front" title="Front HTML">
                                            <AceEditor
                                                mode="html"
                                                theme="github"
                                                onChange={_.throttle((e) => this.handleChange('frontHTML', e), 100)}
                                                value={this.state.selectedCardType.frontHTML}
                                                name="frontHTML"
                                                width="100%"
                                                editorProps={{ $blockScrolling: true }}
                                                enableBasicAutocompletion={true}
                                                enableLiveAutocompletion={true}
                                                setOptions={{
                                                    tabSize: 4,
                                                    useWorker: false
                                                }}
                                            />
                                        </Tab>
                                        <Tab eventKey="back" title="Back HTML">
                                            <AceEditor
                                                mode="html"
                                                theme="github"
                                                onChange={_.throttle((e) => this.handleChange('backHTML', e), 100)}
                                                value={this.state.selectedCardType.backHTML}
                                                name="backHTML"
                                                width="100%"
                                                editorProps={{ $blockScrolling: true }}
                                                enableBasicAutocompletion={true}
                                                enableLiveAutocompletion={true}
                                                setOptions={{
                                                    tabSize: 4,
                                                    useWorker: false
                                                }}
                                            />
                                        </Tab>
                                        <Tab eventKey="styling" title="CSS">
                                            <AceEditor
                                                mode="css"
                                                theme="github"
                                                onChange={_.throttle((e) => this.handleChange('css', e), 100)}
                                                value={this.state.selectedCardType.css}
                                                name="css"
                                                width="100%"
                                                editorProps={{ $blockScrolling: true }}
                                                enableBasicAutocompletion={true}
                                                enableLiveAutocompletion={true}
                                                setOptions={{
                                                    tabSize: 4,
                                                    useWorker: false
                                                }}
                                            />
                                        </Tab>
                                    </Tabs>
                                </Col>
                                <Col>
                                    <Tabs defaultActiveKey="front" id="preview-tabs" onSelect={() => this.setState({ state: this.state })}>
                                        <Tab eventKey="front" title="Front Preview" >
                                            <div dangerouslySetInnerHTML={{ __html: this.htmlFor(this.state.selectedCardType, 'frontHTML', 'front') }}></div>
                                        </Tab>
                                        <Tab eventKey="back" title="Back Preview">
                                            <div dangerouslySetInnerHTML={{ __html: this.htmlFor(this.state.selectedCardType, 'backHTML', 'back') }}></div>
                                        </Tab>
                                    </Tabs>
                                </Col>
                            </Row>}
                        </Col>
                        <Col xs={4}>
                            <Button block variant="primary" className="mb-3" onClick={() => this.toggleCreateFieldModal(true)}>Add Field</Button>
                            <Table striped bordered hover>
                                <thead>
                                    <tr>
                                        <th>Name</th>
                                        <th className="text-center">Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {this.state.fields.map(field => {
                                        return (<tr>
                                            <td className="align-middle">{field.name}</td>
                                            <td className="align-middle text-center">
                                                <Button variant="danger" onClick={() => this.showDeleteFieldModal(field)}><i className="bi bi-trash"></i></Button>
                                            </td>
                                        </tr>);
                                    })}
                                </tbody>
                            </Table>
                        </Col>
                    </Row>
                </div>}

                <AddCardTypeModal noteType={this.state.noteType} show={this.state.showAddCardTypeModal} onHide={() => this.toggleAddCardType(false)} onSuccess={() => this.toggleAddCardType(false)} />
                <CreateFieldModal noteType={this.state.noteType} show={this.state.showCreateFieldModal} onHide={() => this.toggleCreateFieldModal(false)} onSuccess={() => this.toggleCreateFieldModal(false)} />
                <DeleteFieldModal noteType={this.state.noteType} field={this.state.showDeleteFieldModal} didDelete={() => this.showDeleteFieldModal(null)} didCancel={() => this.showDeleteFieldModal(null)} onHide={() => this.showDeleteFieldModal(null)} />
            </div>
        );
    }
}

export default withRouter(NoteType);
