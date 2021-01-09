import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

import ContentEditable from './../Common/ContentEditable';
import DeleteWordModal from './Modals/DeleteWordModal';

class Words extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showDeleteModal: null,
            words: []
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch('/api/lists/words');
        if (response.ok) {
            const words = await response.json();
            this.setState({ words });
        }
    }

    async showDeleteModal(word) {
        this.setState({
            showDeleteModal: word
        });
        await this.load();
    }

    async updateNote(word, note) {
        word.note = note;
        await fetch(`/api/lists/word/${word.id}`, {
            method: 'PUT',
            body: JSON.stringify(word),
            headers: {
                'Content-Type': 'application/json'
            }
        });
    }

    render() {
        return (
            <div>
                <h2>Lists <small className="text-muted">{this.state.words.length} Words(s)</small></h2>
                <hr/>
                <Table striped bordered hover>
                    <thead>
                        <tr>
                            <th className="text-center col-3">Word</th>
                            <th className="text-center col-auto">Note</th>
                            <th className="text-center col-1">Lookups</th>
                            <th className="text-center col-1">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.words.map((word, i) => {
                            return (<tr key={i}>
                                <td className="align-middle">{word.value}</td>
                                <td className="align-middle">
                                    <ContentEditable value={word.note} onChange={(e) => this.updateNote(word, e.target.value)} className='form-control h-auto text-break plaintext' />
                                </td>
                                <td className="align-middle text-center">{word.lookups}</td>
                                <td className="align-middle text-center">
                                    <Button variant="danger" onClick={() => this.showDeleteModal(word)}><i className="bi bi-trash"></i></Button>
                                </td>
                            </tr>);
                        })}
                    </tbody>
                </Table>

                <DeleteWordModal word={this.state.showDeleteModal} show={this.state.showDeleteModal} didDelete={() => this.showDeleteModal(null)} didCancel={() => this.showDeleteModal(null)} onHide={() => this.showDeleteModal(null)} />
            </div>
        );
    }
}

export default Words;
