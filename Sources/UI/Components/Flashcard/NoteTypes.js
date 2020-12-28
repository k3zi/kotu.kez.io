import React from "react";
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

import DeleteNoteTypeModal from "./Modals/DeleteNoteTypeModal";
import CreateNoteTypeModal from "./Modals/CreateNoteTypeModal";

class NoteTypes extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showCreateNoteTypeModal: false,
            showDeleteNoteTypeModal: null,
            noteTypes: [],
            invites: []
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch(`/api/flashcard/noteTypes`);
        if (response.ok) {
            const noteTypes = await response.json();
            this.setState({ noteTypes });
        }
    }

    async toggleCreateNoteTypeModal(show) {
        this.setState({
            showCreateNoteTypeModal: show
        });
        await this.load();
    }

    async showDeleteNoteTypeModal(noteType) {
        this.setState({
            showDeleteNoteTypeModal: noteType
        });
        await this.load();
    }

    render() {
        return (
            <div>
                <h2>Flashcard <small className="text-muted">{this.state.noteTypes.length} Note Types(s)</small></h2>
                <Button variant="primary" onClick={() => this.toggleCreateNoteTypeModal(true)}>Create Note Type</Button>
                <hr/>
                <Table striped bordered hover>
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th className="text-center">Fields</th>
                            <th className="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.noteTypes.map(noteType => {
                            return (<tr>
                                <td className="align-middle">{noteType.name}</td>
                                <td className="align-middle">{noteType.fields.map(f => f.name).join(', ')}</td>
                                <td className="align-middle text-center">
                                    <LinkContainer to={`/flashcard/type/${noteType.id}`}>
                                        <Button variant="primary"><i class="bi bi-arrow-right"></i></Button>
                                    </LinkContainer>
                                    {" "}
                                    <Button variant="danger" onClick={() => this.showDeleteNoteTypeModal(noteType)}><i class="bi bi-trash"></i></Button>
                                </td>
                            </tr>)
                        })}
                    </tbody>
                </Table>

                <CreateNoteTypeModal show={this.state.showCreateNoteTypeModal} onHide={() => this.toggleCreateNoteTypeModal(false)} onSuccess={() => this.toggleCreateNoteTypeModal(false)} />
                <DeleteNoteTypeModal noteType={this.state.showDeleteNoteTypeModal} didDelete={() => this.showDeleteNoteTypeModal(null)} didCancel={() => this.showDeleteNoteTypeModal(null)} onHide={() => this.showDeleteNoteTypeModal(null)} />
            </div>
        )
    }
}

export default NoteTypes;
