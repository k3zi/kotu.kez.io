import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Pagination from 'react-bootstrap-4-pagination';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

import DeleteNoteModal from './Modals/DeleteNoteModal';

class Notes extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showDeleteNoteModal: null,
            notes: [],
            metadata: {
                page: 1,
                per: 15,
                total: 0
            }
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch(`/api/flashcard/notes?page=${this.state.metadata.page}&per=${this.state.metadata.per}`);
        if (response.ok) {
            const result = await response.json();

            this.setState({
                notes: result.items,
                metadata: result.metadata
            });
        }
    }

    async showDeleteNoteModal(note) {
        this.setState({
            showDeleteNoteModal: note
        });
        await this.load();
    }

    loadPage(page) {
        const metadata = this.state.metadata;
        metadata.page = page;
        this.load();
    }

    render() {
        return (
            <div>
                <h2>Anki <small className="text-muted">{this.state.metadata.total} Note(s)</small></h2>
                <hr/>
                <Table striped bordered hover>
                    <thead>
                        <tr>
                            <th className="text-center">Sort Field</th>
                            <th className="text-center">Cards</th>
                            <th className="text-center">Note Type</th>
                            <th className="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.notes.map((note, i) => {
                            return (<tr key={i}>
                                <td className="align-middle">{note.fieldValues[0].value}</td>
                                <td className="align-middle text-center text-primary">{note.cards.length}</td>
                                <td className="align-middle text-center text-primary">{note.noteType.name}</td>
                                <td className="align-middle text-center">
                                    <LinkContainer to={`/flashcard/note/${note.id}`}>
                                        <Button variant="primary"><i className="bi bi-arrow-right"></i></Button>
                                    </LinkContainer>
                                    <div className='w-100 d-block d-md-none'></div>
                                    <Button className='mt-2 mt-md-0 ms-0 ms-md-2' variant="danger" onClick={() => this.showDeleteNoteModal(note)}><i className="bi bi-trash"></i></Button>
                                </td>
                            </tr>);
                        })}
                    </tbody>
                </Table>

                <Pagination totalPages={Math.ceil(this.state.metadata.total / this.state.metadata.per)} currentPage={this.state.metadata.page} showMax={7} onClick={(i) => this.loadPage(i)} />

                <DeleteNoteModal note={this.state.showDeleteNoteModal} didDelete={() => this.showDeleteNoteModal(null)} didCancel={() => this.showDeleteNoteModal(null)} onHide={() => this.showDeleteNoteModal(null)} />
            </div>
        );
    }
}

export default Notes;